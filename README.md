# FSEGN Study Groups (Beta Étudiante)

> Application multiplateforme conçue pour les étudiants de **1ère année Licence Informatique de Gestion (Business Computing)** à la **Faculté des Sciences Économiques et de Gestion de Nabeul (FSEGN)**, **Université de Carthage**, Tunisie.

L’application permet aux étudiants de créer des communautés d’étude durables autour de leurs cours, échanger dans un chat commun et planifier plusieurs rencontres en présentiel au fil du temps. Chaque rencontre garde son horaire, son lieu et son suivi de présence sans fermer le groupe ni sa conversation.

---

## Sommaire

1. [Périmètre & Cohorte Beta](#périmètre--cohorte-beta)
2. [Matières de l'Emploi du Temps (12 Cours)](#matières-de-lemploi-du-temps-12-cours)
3. [Architecture & Choix Techniques](#architecture--choix-techniques)
4. [Politique de Coût \$0 (Supabase Free Tier)](#politique-de-coût-0-supabase-free-tier)
5. [Installation & Démarrage](#installation--démarrage)
6. [Configuration Supabase (Pas à Pas)](#configuration-supabase-pas-à-pas)
7. [Exécution sur Android et iOS](#exécution-sur-android-et-ios)
8. [Guide de Test & Smoke-Test Checklist](#guide-de-test--smoke-test-checklist)
9. [Sécurité, Confidentialité & Règles Métier](#sécurité-confidentialité--règles-métier)
10. [Évolutivité du Modèle](#évolutivité-du-modèle)
11. [Groupes durables et rencontres répétées](#groupes-durables-et-rencontres-répétées)

---

## Périmètre & Cohorte Beta

- **Université** : Université de Carthage
- **Établissement** : Faculté des Sciences Économiques et de Gestion de Nabeul (FSEGN)
- **Niveau** : 1ère année Licence (L1)
- **Filière** : Informatique de Gestion (Business Computing)
- **Mode de présence** : En présentiel sur le campus (Bibliothèque, Salles de lecture, Amphis, Espaces verts).

---

## Matières de l'Emploi du Temps (12 Cours)

Les 12 matières ci-dessous correspondent exactement au libellé de l’emploi du temps du semestre fourni pour la cohorte L1 Business Computing :

1. **Statistique et probabilité**
2. **Comptabilité générale**
3. **Culture de l’IA**
4. **Systèmes logiques, architecture et ordinateurs**
5. **Algorithmique et structures**
6. **Systèmes d’exploitation**
7. **Analyse**
8. **Principes de gestion 1**
9. **Technologie Web et programmation**
10. **Study Skills 1**
11. **Anglais fondamental**
12. **Digital Skills**

> [!NOTE]
> **Saisie libre du sujet/chapitre** : Le chapitre, la leçon ou le sujet de révision (ex. *« Chapitre 3 : Pointeurs et listes chaînées »*, *« TD 2 : Séries numériques et intégrales »*) est un **champ texte libre**. Les étudiants peuvent filtrer et rechercher précisément par mot-clé de chapitre.

---

## Architecture & Choix Techniques

```text
lib/
├── core/
│   ├── constants/       # 12 matières de l'emploi du temps, constantes de cohorte
│   ├── env/             # Détection .env et bascule automatique Mode Démo
│   └── theme/           # Thème FSEGN / Carthage (Navy & Teal, contrastes a11y)
├── data/
│   ├── models/          # Modèles de domaine immuables (Profil, Groupe, Membre, Message, Assiduité)
│   ├── services/        # SupabaseClient & LocalDemoService (offline testbed)
│   └── repositories/    # Auth, Groupes, Chat (Realtime + Fallback), Assiduité (RPCs)
├── ui/
│   ├── core/            # ResponsiveScaffold, Bannières Démo/Cohorte, UiHelpers
│   └── features/
│       ├── auth/        # Écrans Connexion, Inscription, AuthGate
│       ├── groups/      # Liste des groupes, Filtres, Création, Détails du groupe
│       ├── chat/        # Messagerie instantanée avec secours manuel
│       ├── profile/     # Profil, Jauge de fiabilité, Historique d'assiduité
│       └── home/        # Barre de navigation principale
└── main.dart
```

---

## Politique de Coût \$0 (Supabase Free Tier)

L'application a été strictement développée pour le plan **Supabase Free** :
- **Authentification par Email / Mot de passe** uniquement (aucun coût de SMS/OTP payant).
- **Clé Publique Anon uniquement** : la clé `service_role` n'est **jamais** incluse dans l'application mobile.
- **Limitation d'inactivité du Free Tier** : Les projets gratuits Supabase se mettent en pause après **7 jours d'inactivité continue**. Si l'application affiche une erreur de réseau au bout de plusieurs semaines, il suffit d'aller sur le [Dashboard Supabase](https://supabase.com/dashboard) et de cliquer sur **« Restore project »**. Aucun abonnement payant n'est requis.

---

## Installation & Démarrage

### Prérequis
- Flutter SDK (version `>= 3.22.0` / Dart `>= 3.10.0`)
- Git

### 1. Cloner ou ouvrir le projet
Emplacement du projet sur votre machine :
```powershell
C:\Users\Anoula Jabally\Documents\fsegn_study_groups
```

### 2. Installer les dépendances Flutter
Dans le dossier du projet :
```powershell
flutter pub get
```

### 3. Exécuter les tests automatisés
Vérifiez que la suite de tests valide (7/7 tests) :
```powershell
flutter test
```

### 4. Vérifier l'analyse statique
```powershell
dart analyze
```

---

## Configuration Supabase (Pas à Pas)

L'application fonctionne en **double mode** :
- **Sans clés** : elle s'exécute immédiatement en **Mode Démo Local** avec des données d’essai L1 FSEGN complètes.
- **Avec clés** : elle se connecte directement à votre base Supabase en temps réel.

Pour connecter votre propre instance Supabase :

### Étape 1 : Créer un projet Supabase gratuit
1. Rendez-vous sur [supabase.com](https://supabase.com) et créez un compte gratuit.
2. Créez un nouveau projet (ex: `fsegn-study-groups`, région `eu-central-1` ou la plus proche de la Tunisie).

### Étape 2 : Exécuter les migrations SQL dans l’ordre
1. Dans le Dashboard Supabase, ouvrez l'onglet **SQL Editor** dans le menu de gauche.
2. Cliquez sur **New query**.
3. Exécutez chaque fichier de `supabase/migrations/` dans l’ordre chronologique, en commençant par :
   ```text
   supabase/migrations/20261018_initial_schema.sql
   ```
4. Collez chaque fichier dans une nouvelle requête et cliquez sur **Run** avant de passer au suivant.
5. La migration `20261031120000_persistent_groups_and_sessions.sql` transforme les groupes existants en communautés durables et conserve leurs rencontres et leurs historiques.
6. Les premières migrations créent automatiquement :
   - La table `profiles` sécurisée (sans stockage d'email).
   - La table `study_groups` avec contrainte sur les 12 matières.
   - La table `group_members` avec vérification transactionnelle de capacité.
   - La table `group_messages` pour le chat.
   - Les politiques de sécurité RLS (Row Level Security).
   - Les fonctions stockées transactionnelles `join_study_group`, `set_attendance_confirmation`, `record_my_attendance`.
   - La publication temps réel pour le chat.

### Étape 3 : Vérifier l'authentification Email
1. Dans le Dashboard Supabase, allez dans **Authentication** -> **Providers**.
2. Assurez-vous que le provider **Email** est activé.
3. Pour des tests beta rapides sans validation par mail, vous pouvez désactiver **« Confirm email »** sous **Authentication** -> **URL Configuration / Email Templates** si vous le souhaitez.

### Étape 4 : Activer Supabase Realtime sur les messages
Le script SQL inclut déjà `ALTER PUBLICATION supabase_realtime ADD TABLE public.group_messages;`.
Vous pouvez le vérifier dans **Database** -> **Replication** -> `supabase_realtime` (la table `group_messages` doit être cochée).

### Étape 5 : Configurer le fichier `.env`
1. Récupérez vos clés dans **Project Settings** -> **API** :
   - **Project URL** (`https://xyzcompany.supabase.co`)
   - **Project API Keys** -> `anon` / `public`
2. Ouvrez le fichier `.env` à la racine de `fsegn_study_groups` :
   ```env
   SUPABASE_URL=https://votre-projet.supabase.co
   SUPABASE_ANON_KEY=eyJhbGciOi...
   ```
3. Sauvegardez le fichier.

---

## Exécution sur Android et iOS

### Sur Android
1. Démarrez un émulateur Android (via Android Studio ou commande `android`) ou branchez un smartphone Android en mode Débogage USB.
2. Lancez l'application :
   ```powershell
   flutter run -d android
   ```

### Sur iOS (macOS requis pour compilation native)
1. Ouvrez le simulateur iOS (`open -a Simulator`).
2. Lancez l'application :
   ```bash
   flutter run -d ios
   ```

---

## Guide de Test & Smoke-Test Checklist

Pour valider le fonctionnement complet de l'application, suivez cette checklist de test :

### 1. Authentification & Profil
- [ ] **Inscription** : Remplissez Nom, Prénom, Bio facultative, Email et Mot de passe.
- [ ] **Protection d'email** : Vérifiez que l'email est marqué comme privé sur le profil et n'apparaît nulle part sur les cartes publiques de groupe ou la liste des membres.
- [ ] **Badge de Cohorte** : Vérifiez l'affichage de *« FSEGN • L1 Business Computing • Carthage »*.

### 2. Découverte des Groupes d'Étude
- [ ] **Recherche plein texte** : Saisissez un mot-clé (ex: *« pointeurs »* ou *« karnaugh »*) dans la barre de recherche.
- [ ] **Filtre par matière** : Cliquez sur les puces horizontales pour filtrer par l'une des 12 matières.
- [ ] **Filtres avancés** : Ouvrez le panneau de filtres pour tester le filtre *« Places disponibles uniquement »* et le filtre par date.
- [ ] **Pull-to-refresh** : Tirez la liste vers le bas pour actualiser.

### 3. Création d'un Groupe d'Étude
- [ ] Cliquez sur le bouton flottant **« Nouveau groupe »**.
- [ ] Choisissez le nom, une icône emoji, la matière, le sujet et la limite de membres.
- [ ] Publiez le groupe sans devoir choisir une date ni un lieu.
- [ ] Vérifiez que le créateur est inscrit comme premier membre.
- [ ] Depuis le groupe, proposez une rencontre en présentiel; elle apparaît dans la liste des rencontres du groupe.
- [ ] Après une rencontre terminée, vérifiez que le même groupe et son chat restent disponibles et qu'une autre rencontre peut être ajoutée.

### 4. Rejoindre un Groupe & Capacité
- [ ] Ouvrez un groupe ayant des places disponibles.
- [ ] Cliquez sur **« Rejoindre ce groupe d’étude »**.
- [ ] Vérifiez que la jauge de capacité augmente et que votre statut passe à *« Inscrit »*.
- [ ] **Contrôle de saturation** : Vérifiez qu'un groupe plein (ex: le groupe Statistique 4/4) affiche *« Complet »* et empêche toute nouvelle inscription.

### 5. Confirmation de Présence & Assiduité
- [ ] **Avant une rencontre** : Cliquez sur **« Je serai là »** (la confirmation passe au vert).
- [ ] **Annulation** : Vous pouvez annuler la confirmation avant le début de la séance.
- [ ] **Après la rencontre** : Pour une rencontre terminée, cliquez sur **« Déclarer ma présence »**.
- [ ] **Calcul du score** : Déclarez votre présence (+5 pts) ou absence (-15 pts). Vérifiez que le score de fiabilité s'ajuste et reste plafonné entre 0% et 100%.
- [ ] **Idempotence** : Vérifiez qu'il est impossible de soumettre deux fois son assiduité pour la même séance.
- [ ] **Transparence** : Vérifiez l'affichage de la mention du système d’honneur dans la boîte de dialogue et l'historique d'assiduité.

### 6. Messagerie Instantanée de Groupe
- [ ] Ouvrez le détail d'un groupe rejoint, puis cliquez sur **« Ouvrir le Chat du Groupe »**.
- [ ] Envoyez un message : il apparaît instantanément dans la bulle droite.
- [ ] Utilisez le bouton d'actualisation manuelle dans l'AppBar pour tester le mode de secours.

---

## Sécurité, Confidentialité & Règles Métier

1. **Confidentialité des e-mails (Directive #1)** :
   La table publique `public.profiles` ne contient **aucune colonne email**. L'adresse email de l'étudiant reste confinée dans le schéma sécurisé `auth.users` de Supabase. Les requêtes de profil utilisées par les autres étudiants ne peuvent pas extraire les adresses e-mail.
2. **Protection du score de fiabilité & RPC de profil sécurisée** :
   Les requêtes directes d'écriture (`INSERT, UPDATE, DELETE`) sur `public.profiles` depuis les rôles client (`authenticated`, `anon`) sont **strictement révoquées** au niveau de PostgreSQL (`REVOKE INSERT, UPDATE, DELETE ON public.profiles FROM authenticated, anon;`).
   - Pour modifier son nom et sa bio, l'utilisateur passe impérativement par la fonction PostgreSQL `public.update_my_profile(p_display_name, p_bio)`.
   - Cette fonction n'accepte et ne modifie **que** `display_name` et `bio`.
   - Il est techniquement impossible pour un utilisateur de modifier son propre `reliability_score` ou ses informations de cohorte via une requête client.
   - La fonction transactionnelle `record_my_attendance()` reste l'unique vecteur permettant d'ajuster le score de fiabilité.
3. **Sécurité du fichier `.env` (Actif embarqué dans l'application)** :
   Le fichier `.env` inclus dans les assets de l'application contient **uniquement** l'URL publique du projet et la clé client publique (`anon` / `publishableKey`).
   - La clé `service_role` (clé d'administration avec privilèges bypass RLS) n'est **jamais** renseignée dans `.env`, ni dans le code source Dart, ni dans les assets de l'application mobile.
4. **Capacité transactionnelle (Directive #2)** :
   L'inscription à un groupe passe par la fonction PostgreSQL `join_study_group(p_group_id UUID)` munie de `SECURITY DEFINER` et d'un verrou `FOR UPDATE` sur la ligne du groupe. Si deux étudiants cliquent en même temps sur la dernière place restante, un seul est accepté et le second reçoit une exception claire.
5. **Présence non pré-confirmée du créateur (Directive #3)** :
   Le déclencheur d'insertion `handle_new_study_group` crée le créateur avec `role = 'creator'` et `attendance_confirmed = false`. Le créateur doit confirmer activement sa présence au même titre que ses camarades.
6. **Calcul d'assiduité honnête (Directive #4)** :
   La fonction PostgreSQL `record_my_attendance(p_group_id, p_attended)` garantit qu'un étudiant ne peut enregistrer son assiduité qu'une seule fois après la fin de la séance (`attendance_recorded_at IS NULL`), protège le score contre la manipulation et le contraint entre 0% et 100%. Un message explicite rappelle qu'il s'agit d'une autodéclaration sur l'honneur.

---

## Évolutivité du Modèle

Le modèle de données PostgreSQL et les classes de domaine Dart incluent déjà les champs d’extensibilité :
- `university` (par défaut `'Université de Carthage'`)
- `faculty` (par défaut `'FSEGN (Nabeul)'`)
- `licence_year` (par défaut `'L1'`)
- `specialty` (par défaut `'Business Computing'`)
- `cohort_key` (par défaut `'fsegn_l1_bc'`)

Pour ouvrir l'application à la 2ème année (L2), 3ème année (L3), ou à d'autres facultés partenaires (ex: FSEG Mahdia, ISG Tunis, ESCT), il suffit d'ajouter leurs matières et de paramétrer le sélecteur de cohorte sans modifier la structure des tables ni les politiques RLS.

## Groupes durables et rencontres répétées

Un groupe représente maintenant un espace de discussion durable : nom, icône emoji, matière, sujet de travail, description et limite de membres. Il n’exige ni horaire ni lieu lors de sa création. Les membres gardent le même chat d’une semaine à l’autre.

Les rencontres en présentiel sont enregistrées séparément dans `study_sessions`. Un groupe peut en organiser plusieurs; chaque rencontre garde son propre sujet, lieu, horaire, participants et suivi de présence. La migration `supabase/migrations/20261031133304_persistent_groups_and_sessions.sql` ajoute ce modèle et transforme chaque ancienne séance planifiée en première rencontre, en conservant les identifiants de groupe, les conversations et les adhésions existantes.
