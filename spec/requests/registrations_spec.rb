require "rails_helper"

RSpec.describe "Registrations", type: :request do
  def sign_up(email_address: "aki@example.com", password: "password", password_confirmation: password)
    post registration_path, params: { user: { email_address:, password:, password_confirmation: } }
  end

  it "creates an account and logs you in" do
    expect { sign_up }.to change(User, :count).by(1)

    expect(response).to redirect_to(root_url)
    follow_redirect!
    expect(response.body).to include("アカウントを作成しました", "ログアウト")
  end

  it "re-renders the form with Japanese errors" do
    sign_up(password: "short", password_confirmation: "different")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("パスワードは8文字以上で入力してください",
                                     "パスワード（確認）とパスワードの入力が一致しません")
  end

  it "refuses an email address that already has an account" do
    create(:user, email_address: "aki@example.com")

    expect { sign_up }.not_to change(User, :count)
    expect(response.body).to include("メールアドレスはすでに存在します")
  end

  it "limits each IP to 10 sign-ups in 3 minutes" do
    10.times { |n| sign_up(email_address: "user#{n}@example.com") }
    sign_up(email_address: "one-too-many@example.com")

    expect(response).to redirect_to(new_registration_path)
    expect(flash[:alert]).to eq("しばらくしてからもう一度お試しください")
  end
end
