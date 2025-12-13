class PagesController < ApplicationController
  def terms
  end

  def privacy
  end

  def contact
  end

  def create_contact
    # お問い合わせ送信処理
    email = params[:email]
    subject = params[:subject]
    message = params[:message]
    
    # TODO: メール送信処理（後で実装）
    # ContactMailer.contact_form(name, email, subject, message).deliver_later
    
    redirect_to contact_path, notice: 'お問い合わせを送信しました。返信までしばらくお待ちください。'
  end
end
