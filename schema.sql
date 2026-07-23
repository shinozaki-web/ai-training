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
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
        AND p.is_admin = TRUE
        AND p.company_id = profiles.company_id
    )
  );

CREATE POLICY "admin read company surveys"
  ON survey_responses FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN profiles target ON target.id = survey_responses.user_id
      WHERE p.id = auth.uid()
        AND p.is_admin = TRUE
        AND p.company_id = target.company_id
    )
  );

CREATE POLICY "admin read company progress"
  ON section_progress FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN profiles target ON target.id = section_progress.user_id
      WHERE p.id = auth.uid()
        AND p.is_admin = TRUE
        AND p.company_id = target.company_id
    )
  );
