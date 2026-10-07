# GitHub Desktop Setup

## 1. Put this repository on your machine

Extract the repository folder somewhere convenient, for example:

```text
C:\Users\<you>\Documents\AI-Diary
```

## 2. Create the local Git repository with GitHub Desktop

In GitHub Desktop:

1. **File -> Add local repository...**
2. Select the extracted `AI-Diary-Repo-v1` folder.
3. If GitHub Desktop says the folder is not yet a Git repository, choose **create a repository here**.
4. Repository name suggestion: `AI-Diary`.
5. Keep the existing `.gitignore` and files; do not replace this starter content.
6. Make the first commit, for example: `chore: bootstrap AI Diary repository`.
7. Click **Publish repository**.

## 3. Add Vy and Trâm

Collaborator invitations are managed on GitHub.com rather than GitHub Desktop:

1. Open the published repository on GitHub.com.
2. Go to **Settings -> Collaborators** (wording can vary slightly).
3. Invite each teammate by GitHub username/email.
4. They accept the invitation and clone the repository through GitHub Desktop.

## 4. Protect `main`

On GitHub.com, add a branch protection/ruleset for `main` so the team works through Pull Requests. Recommended minimum:

- require a Pull Request before merging;
- require at least one approval;
- block force pushes;
- do not let Codex work directly on `main`.

Phúc remains the final integration reviewer/merger.

## 5. Teammate workflow

Each teammate clones the repository in GitHub Desktop, creates a task branch, opens the folder in Antigravity/VSCode, then runs Codex only on that branch.

Example task branches:

```text
feat/home-daily-prompt
feat/journal-editor
feat/study-screen
feat/album-grid
feat/ai-reflection-api
```

Do not create one permanent branch per person.
