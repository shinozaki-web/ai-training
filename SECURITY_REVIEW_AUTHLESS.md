# 認証なし・端末内保存版 セキュリティレビュー

実施日: 2026-08-25（初回事前アンケート削除後に再確認）

## 対象

- ログイン必須のSupabase版から、認証なし・`localStorage`保存版への変更
- `index.html`、`home.html`、`curriculum.html`、`lesson.html`、`quiz.html`、`badges.html`
- `local-store.js`

## 確認結果

- ブラウザで読み込む本編からSupabase URL・anon key・Auth・Database依存を除去した。
- service role key、GitHub token、OpenAI key、メール認証情報などの秘密情報は追加していない。
- 名前・会社名・進捗・クイズ結果は当該ブラウザの`localStorage`だけに保存し、外部送信しない。
- 入力した名前・会社名は`textContent`で表示し、HTMLとして解釈しない。
- `localStorage`読込時はJSON解析失敗を処理し、既定状態へ安全に戻す。
- 保存する文字列長を制限し、クイズ履歴は最新100件に制限した。
- 教材の要望受付導線は、運営者所有の固定GoogleフォームURLを使用し、利用者入力をURLへ連結しない。
- Googleフォームはリンクを知っている全員が回答できる設定であり、回答は運営者所有のGoogleスプレッドシートへ保存される。
- フォームURLに認証情報や秘密情報は含まれず、外部リンクには`noopener noreferrer`を設定した。
- 旧`feedback.html`はSupabase処理を持たない固定Googleフォームへの案内・リダイレクトに置き換えた。
- 外部送信もカリキュラムの調整も行っていなかった初回事前アンケートを削除し、未回答判定による画面遷移も除去した。
- 外部サイトを開く既存リンクは`noopener noreferrer`を維持している。
- `node scripts/validate-static-app.mjs`が全HTMLを検証済み。

## 意図された制約

- 認証を廃止するため、公開URLを知る人は教材を閲覧できる。機密教材としてのアクセス制御は提供しない。
- 端末・ブラウザ間の同期、管理者による進捗確認、クラウドバックアップは提供しない。
- ブラウザデータの削除により進捗は失われる。
- 旧Supabase版に保存された進捗は自動移行しない。

## 判定

認証なし公開教材としての意図に対する重大・高リスクの問題は確認されなかった。本番公開前に同じ検証を再実行し、Supabase停止前にはデータベースとStorageを別途バックアップすること。
