require "tempfile"

class RecordingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_recording, only: [ :show, :update, :select_accompaniment, :update_accompaniment, :mix, :destroy ]

  def index
    @recordings = current_user.recordings.order(created_at: :desc)
  end

  def show
    unless @recording.accompaniment.attached?
      redirect_to mypage_path, alert: "伴奏ファイルが設定されていません。先に伴奏をアップロードしてください。" and return
    end

    unless @recording.original_audio.attached?
      redirect_to mypage_path, alert: "録音ファイルが見つかりません。" and return
    end
  end

  def new
    @recording = Recording.new
    @selected_video = current_user.videos.last
  end

  def create
    @recording = current_user.recordings.new(recording_params)
    @recording.status = :created
    @recording.recording_delay = 0
    @recording.vocal_gain = 0.5 # デフォルトは0.5（0〜1の範囲）

    respond_to do |format|
      if @recording.save
        # 伴奏ファイルがある場合は調整ページへ、ない場合はマイページへ
        if @recording.accompaniment.attached?
          format.html { redirect_to @recording, notice: "録音ファイルが正常にアップロードされました。タイミングを調整してください。" }
          format.json { render json: { id: @recording.id, redirect_url: recording_path(@recording) }, status: :created }
        else
          format.html { redirect_to mypage_path, notice: "録音ファイルが保存されました。マイページから伴奏ファイルをアップロードすると、タイミング調整が可能になります。" }
          format.json { render json: { id: @recording.id, redirect_url: mypage_path }, status: :created }
        end
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @recording.errors, status: :unprocessable_entity }
      end
    end
  end

  def select_accompaniment
    # recordings/select_accompaniment.html.erb がレンダリングされる
  end

  def update_accompaniment
    if @recording.update(accompaniment: params[:recording][:accompaniment])
      redirect_to @recording, notice: "伴奏ファイルがアップロードされました。タイミングを調整してください。"
    else
      render :select_accompaniment, status: :unprocessable_entity, alert: "伴奏のアップロードに失敗しました。"
    end
  end

  # 調整値の保存（ミキシングは開始しない）
  def update
    if @recording.update(recording_params)
      redirect_to @recording, notice: "調整値が保存されました。"
    else
      flash.now[:alert] = "保存に失敗しました: #{@recording.errors.full_messages.join(', ')}"
      render :show, status: :unprocessable_entity
    end
  end

  # ミキシング処理を開始
  def mix
    # パラメータを取得
    delay_value = params.dig(:recording, :recording_delay)
    gain_value = params.dig(:recording, :vocal_gain)

    Rails.logger.info "RecordingsController#mix: delay=#{delay_value}, gain=#{gain_value}"

    if delay_value.nil? || gain_value.nil?
      redirect_to @recording, alert: "調整値が不正です。もう一度お試しください。"
      return
    end

    # 値を数値に変換
    delay_seconds = delay_value.to_f
    vocal_gain_value = gain_value.to_f

    # recordingに保存
    @recording.recording_delay = delay_seconds
    @recording.vocal_gain = vocal_gain_value

    unless @recording.valid?
      flash[:alert] = "保存に失敗しました: #{@recording.errors.full_messages.join(', ')}"
      redirect_to @recording
      return
    end

    @recording.save!

    Rails.logger.info "RecordingsController#mix: Saved recording with delay=#{@recording.recording_delay}, gain=#{@recording.vocal_gain}"

    unless @recording.ready_for_generation?
      redirect_to @recording, alert: "ミキシングに必要なファイルが揃っていません。"
      return
    end

    @recording.update!(status: :generating)

    begin
      AudioMixingJob.perform_later(@recording.id, delay_seconds, vocal_gain_value)
      Rails.logger.info "RecordingsController#mix: AudioMixingJob enqueued with delay=#{delay_seconds}, gain=#{vocal_gain_value}"
      redirect_to @recording, notice: "調整値を保存し、ミキシング処理を開始しました。完了までしばらくお待ちください。"
    rescue => e
      Rails.logger.error "RecordingsController#mix: Failed to enqueue AudioMixingJob: #{e.message}"
      @recording.update!(status: :failed, error_message: e.message)
      redirect_to @recording, alert: "ミキシング処理の開始に失敗しました。"
    end
  end

  def destroy
    @recording.destroy
    redirect_to mypage_path, notice: "録音ファイルは正常に削除されました。"
  end

  private

  def set_recording
    @recording = current_user.recordings.find_by(id: params[:id])

    unless @recording
      flash[:alert] = "指定された録音が見つからないか、アクセス権がありません。"
      redirect_to mypage_path
    end
  end

  def recording_params
    params.require(:recording).permit(:title, :original_audio, :accompaniment, :recording_delay, :vocal_gain)
  end
end
