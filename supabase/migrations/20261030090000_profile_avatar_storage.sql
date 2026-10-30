-- Profile photos: public read, authenticated owner-only writes.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS avatar_path TEXT;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', true, 5242880, ARRAY['image/jpeg', 'image/png'])
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Avatar images are publicly readable" ON storage.objects;
CREATE POLICY "Avatar images are publicly readable"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Students upload their own avatar" ON storage.objects;
CREATE POLICY "Students upload their own avatar"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  );

DROP POLICY IF EXISTS "Students update their own avatar" ON storage.objects;
CREATE POLICY "Students update their own avatar"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  )
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  );

-- Replace the existing profile RPC to allow only the authenticated user's own
-- avatar path while preserving its protection for cohort and reliability fields.
DROP FUNCTION IF EXISTS public.update_my_profile(TEXT, TEXT);

CREATE FUNCTION public.update_my_profile(
  p_display_name TEXT,
  p_bio TEXT DEFAULT NULL,
  p_avatar_path TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_trimmed_name TEXT := TRIM(p_display_name);
  v_trimmed_bio TEXT := NULLIF(TRIM(p_bio), '');
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF char_length(v_trimmed_name) < 2 OR char_length(v_trimmed_name) > 60 THEN
    RAISE EXCEPTION 'Le nom d’affichage doit comporter entre 2 et 60 caractères.';
  END IF;

  IF v_trimmed_bio IS NOT NULL AND char_length(v_trimmed_bio) > 250 THEN
    RAISE EXCEPTION 'La bio ne peut pas dépasser 250 caractères.';
  END IF;

  IF p_avatar_path IS NOT NULL
     AND p_avatar_path !~ ('^' || v_user_id::text || '/avatar\.(jpg|png)$') THEN
    RAISE EXCEPTION 'Chemin de photo invalide.';
  END IF;

  UPDATE public.profiles
  SET display_name = v_trimmed_name,
      bio = v_trimmed_bio,
      avatar_path = COALESCE(p_avatar_path, avatar_path),
      updated_at = now()
  WHERE id = v_user_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Profil mis à jour avec succès'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.update_my_profile(TEXT, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.update_my_profile(TEXT, TEXT, TEXT)
  TO authenticated;
