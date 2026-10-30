-- The project already has the private student-avatars bucket and
-- owner-scoped Storage policies. Reuse those controls; only extend the profile RPC
-- to store a path in that existing bucket.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS avatar_path TEXT;

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

  -- Match the existing Storage policy: <user-id>/<numeric-name>.<image-ext>.
  IF p_avatar_path IS NOT NULL
     AND p_avatar_path !~ ('^' || v_user_id::text || '/[0-9]+[.](jpg|png|webp)$') THEN
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

NOTIFY pgrst, 'reload schema';
