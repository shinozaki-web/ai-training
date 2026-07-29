# 改善リクエスト自動化の初期設定

生徒の報告から実装PRまでの経路は次のとおりです。

1. 生徒が `feedback.html` から送信
2. Supabase Edge Function が保存し、担当者付きGitHub Issueと任意のメールで通知
3. 管理者が `admin.html` で「承認して実装を開始」
4. Edge Function が GitHub Actions を起動
5. Codex が修正し、検証後にPRを作成
6. PRリンクが管理画面とメールに届く

## 1. Supabase

Supabase SQL Editor で
`supabase/migrations/20260729090000_feedback_automation.sql` を実行します。
既存環境へ安全に追加でき、管理者向けRLSポリシーも再帰しない形へ更新します。

Supabase CLI をインストールしてログイン後、プロジェクトルートで以下を実行します。

```sh
supabase link --project-ref lnszvaeomaeukazkfilm
supabase functions deploy feedback-submit --no-verify-jwt
supabase functions deploy feedback-approve --no-verify-jwt
supabase functions deploy feedback-status --no-verify-jwt
```

Edge Function の Secrets を設定します。

```sh
supabase secrets set \
  GITHUB_TOKEN=github_fine_grained_token \
  GITHUB_REPOSITORY=shinozaki-web/ai-training \
  RESEND_API_KEY=re_xxx \
  NOTIFICATION_EMAIL=通知を受け取るメールアドレス \
  NOTIFICATION_FROM="AI研修 <feedback@example.com>" \
  ADMIN_URL=https://公開URL/admin.html \
  AUTOMATION_CALLBACK_SECRET=十分に長いランダム文字列
```

`GITHUB_TOKEN` は対象リポジトリだけに限定し、Actions の write 権限だけを付与します。
メール通知を使わない場合、`RESEND_API_KEY`、`NOTIFICATION_EMAIL`、
`NOTIFICATION_FROM` は省略できます。管理画面と担当者付きGitHub Issueには常に表示されます。

## 2. GitHub

リポジトリの Actions secrets に以下を登録します。

- `OPENAI_API_KEY`: Codex GitHub Action 用の OpenAI API key。公式Actionがキーを
  Responses APIプロキシへ隔離し、Codex本体へ直接公開しません。
- `FEEDBACK_CALLBACK_URL`: `https://lnszvaeomaeukazkfilm.supabase.co/functions/v1/feedback-status`
- `AUTOMATION_CALLBACK_SECRET`: Supabase 側と同じランダム文字列

Settings → Actions → General で Workflow permissions を Read and write にし、
「Allow GitHub Actions to create and approve pull requests」を有効にします。

`master` は保護ブランチにし、PRを必須にしてください。承認ボタンは実装PRを作りますが、
本番反映はPRのマージ時だけ行われます。
自動作成されたPRがマージされると、`complete-feedback.yml` が管理画面の状態を
「対応済み」へ更新します。

## 3. 動作確認

1. 生徒アカウントで1件送信する
2. メールと管理画面の両方に表示されることを確認する
3. 管理者で承認する
4. GitHub Actions が起動し、PRが作られることを確認する
5. PRリンクが管理画面に表示されることを確認する
