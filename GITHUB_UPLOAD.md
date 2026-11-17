# Upload this starter kit to GitHub

The starter kit was created locally because GitHub could not be reached from the current session.

From a terminal:

```bash
cd path/to/ShelterWise
git init
git add .
git commit -m "Add ShelterWise hackathon starter kit"
git branch -M main
git remote add origin https://github.com/Bornism/A4I2026-challenge-housing.git
git push -u origin main
```

**Important:** If the destination repository already contains files or commits, do not force-push. First clone/pull the remote on your machine, copy these files into that working tree, inspect the diff, then commit and push. This avoids overwriting challenge starter files.

Suggested safe workflow when the remote already exists:

```bash
git clone https://github.com/Bornism/A4I2026-challenge-housing.git
# Copy the contents of this ShelterWise folder into the cloned repository.
cd A4I2026-challenge-housing
git status
git add README.md docs prompts slides GITHUB_UPLOAD.md
git commit -m "Add ShelterWise project plan and team prompts"
git push
```
