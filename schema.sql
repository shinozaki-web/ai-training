-- ① 会社テーブル
CREATE TABLE companies (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  code TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ② プロフィール（Supabase authと紐づく）
CREATE TABLE profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  name TEXT NOT NULL,
  company_id UUID REFERENCES companies(id),
  is_admin BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ③ 事前アンケート回答
CREATE TABLE survey_responses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) UNIQUE,
  q1_role TEXT,
  q2_frequency TEXT,
  q3_time_consuming TEXT,
  q4_priority TEXT,
  q5_concerns TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ④ モジュール・セクション進捗
CREATE TABLE section_progress (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id),
  module_id INTEGER NOT NULL,
  section_id INTEGER NOT NULL,
  completed_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, module_id, section_id)
);

-- ⑤ クイズ結果
CREATE TABLE quiz_results (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id),
  module_id INTEGER NOT NULL,
  score INTEGER NOT NULL,
  total INTEGER NOT NULL,
  completed_at TIMESTAMPTZ DEFAULT NOW()
);

-- ⑥ 取得バッジ
CREATE TABLE user_badges (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id),
  badge_id TEXT NOT NULL,
  earned_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, badge_id)
);

-- ⑦ RLS（行レベルセキュリティ）有効化
ALTER TABLE profiles        ENABLE ROW LEVEL SECURITY;
ALTER TABLE survey_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE section_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_results     ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_badges      ENABLE ROW LEVEL SECURITY;

-- RLS 内で profiles を直接自己参照すると再帰するため、権限判定だけを
-- SECURITY DEFINER 関数へ隔離する。search_path を固定し、authenticated のみ実行可。
CREATE OR REPLACE FUNCTION is_company_admin(target_company_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
      AND is_admin = TRUE
      AND company_id = target_company_id
  );
$$;

CREATE OR REPLACE FUNCTION can_admin_user(target_user_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM profiles admin_profile
    JOIN profiles target_profile
      ON target_profile.id = target_user_id
    WHERE admin_profile.id = auth.uid()
      AND admin_profile.is_admin = TRUE
      AND admin_profile.company_id = target_profile.company_id
  );
$$;

REVOKE ALL ON FUNCTION is_company_admin(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION can_admin_user(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION is_company_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION can_admin_user(UUID) TO authenticated;

-- 自分のデータのみ読み書き可
-- profiles は操作ごとに分割（is_admin の権限昇格を防ぐ）
CREATE POLICY "own profile read"   ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "own profile insert" ON profiles FOR INSERT WITH CHECK (auth.uid() = id AND is_admin = false);
CREATE POLICY "own profile update" ON profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id
    AND is_admin = (SELECT is_admin FROM profiles WHERE id = auth.uid())
  );

CREATE POLICY "own survey"    ON survey_responses FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own progress"  ON section_progress FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own quiz"      ON quiz_results     FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own badges"    ON user_badges      FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 管理者は同じ会社の全データを読める
CREATE POLICY "admin read company profiles"
  ON profiles FOR SELECT
  USING (is_company_admin(profiles.company_id));

CREATE POLICY "admin read company surveys"
  ON survey_responses FOR SELECT
  USING (can_admin_user(survey_responses.user_id));

CREATE POLICY "admin read company progress"
  ON section_progress FOR SELECT
  USING (can_admin_user(section_progress.user_id));

CREATE POLICY "admin read company badges"
  ON user_badges FOR SELECT
  USING (can_admin_user(user_badges.user_id));

-- ⑧ 改善・拡充・不具合の報告
CREATE TABLE feedback_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES profiles(id),
  company_id UUID NOT NULL REFERENCES companies(id),
  category TEXT NOT NULL CHECK (category IN ('bug', 'improvement', 'content')),
  title TEXT NOT NULL CHECK (char_length(title) BETWEEN 1 AND 120),
  description TEXT NOT NULL CHECK (char_length(description) BETWEEN 1 AND 4000),
  page_url TEXT CHECK (page_url IS NULL OR char_length(page_url) <= 500),
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'implementing', 'in_review', 'completed', 'rejected', 'failed')),
  admin_note TEXT CHECK (admin_note IS NULL OR char_length(admin_note) <= 1000),
  approved_by UUID REFERENCES profiles(id),
  approved_at TIMESTAMPTZ,
  pull_request_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX feedback_requests_company_status_created_idx
  ON feedback_requests(company_id, status, created_at DESC);

ALTER TABLE feedback_requests ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON TABLE feedback_requests TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE feedback_requests TO service_role;

-- 生徒は自分の報告だけを参照できる。作成・承認は Edge Function 経由。
CREATE POLICY "own feedback read"
  ON feedback_requests FOR SELECT
  USING (auth.uid() = user_id);

-- 管理者は同じ会社の報告だけを参照できる。
CREATE POLICY "admin read company feedback"
  ON feedback_requests FOR SELECT
  USING (is_company_admin(feedback_requests.company_id));
