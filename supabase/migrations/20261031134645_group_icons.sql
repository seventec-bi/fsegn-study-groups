-- Use a lightweight emoji for group identity instead of uploaded group photos.
-- The legacy cover column and storage bucket are retained to avoid deleting files.

ALTER TABLE public.study_groups
  ADD COLUMN IF NOT EXISTS icon_emoji TEXT NOT NULL DEFAULT '📚';

UPDATE public.study_groups
SET icon_emoji = CASE subject
  WHEN 'Statistique et probabilité' THEN '📊'
  WHEN 'Comptabilité générale' THEN '🧮'
  WHEN 'Culture de l’IA' THEN '🤖'
  WHEN 'Systèmes logiques, architecture et ordinateurs' THEN '⚙️'
  WHEN 'Algorithmique et structures' THEN '💻'
  WHEN 'Systèmes d’exploitation' THEN '🖥️'
  WHEN 'Analyse' THEN '📐'
  WHEN 'Principes de gestion 1' THEN '📈'
  WHEN 'Technologie Web et programmation' THEN '🌐'
  WHEN 'Study Skills 1' THEN '📝'
  WHEN 'Anglais fondamental' THEN '🗣️'
  WHEN 'Digital Skills' THEN '✨'
  ELSE '📚'
END
WHERE icon_emoji IS NULL OR icon_emoji = '📚';

ALTER TABLE public.study_groups
  ADD CONSTRAINT study_groups_icon_emoji_length
  CHECK (char_length(icon_emoji) BETWEEN 1 AND 8);

NOTIFY pgrst, 'reload schema';
