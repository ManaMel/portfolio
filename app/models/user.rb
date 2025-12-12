class User < ApplicationRecord
  validates :password, length: { minimum: 6 }, if: -> { new_record? || changes[:crypted_password] }
  validates :password, confirmation: true, if: -> { new_record? || changes[:crypted_password] }
  validates :password_confirmation, presence: true, if: -> { new_record? || changes[:crypted_password] }
  validates :email, presence: true, uniqueness: true

  has_many :videos, dependent: :destroy
  has_many :recordings, dependent: :destroy
  has_many :video_generations, dependent: :destroy
  has_one :profile, dependent: :destroy
  has_one :youtube_credential, dependent: :destroy

  def youtube_authenticated?
    youtube_credential&.valid_token?
  end

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  after_create :build_default_profile

  private

  def build_default_profile
    create_profile!(
      name: "",
      musical_carrer: "",
      avatar: ""
    )
  end
end
