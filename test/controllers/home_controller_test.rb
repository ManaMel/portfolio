require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)  # fixtures/users.yml に定義されたユーザー
    sign_in @user        # ← ログインする
  end
  
  test "should get index" do
    get home_index_url
    assert_response :success
  end
end
