#!/usr/bin/env python3

import os
import yaml
import requests
import logging
import time
import subprocess

# Setup logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")

# Read GitHub token from environment variable
GITHUB_API_TOKEN = os.getenv("GITHUB_API_TOKEN")
if not GITHUB_API_TOKEN:
    logging.error("❌ GITHUB_API_TOKEN environment variable not set.")
    exit(1)

# GitHub API headers
HEADERS = {
    "Authorization": f"token {GITHUB_API_TOKEN}",
    "Accept": "application/vnd.github+json"
}

def load_repos(file_path):
    with open(file_path, "r") as f:
        config = yaml.safe_load(f)
    return config.get("repos", [])

def set_visibility(owner, repo, private):
    url = f"https://api.github.com/repos/{owner}/{repo}"
    response = requests.get(url, headers=HEADERS)
    if response.status_code != 200:
        logging.error(f"Failed to fetch repo {owner}/{repo}: {response.status_code}")
        return

    current = response.json().get("private", None)
    if current == private:
        logging.info(f"{owner}/{repo} already {'private' if private else 'public'}. No change.")
        return

    response = requests.patch(url, json={"private": private}, headers=HEADERS)
    if response.status_code == 200:
        logging.info(f"✔ Updated {owner}/{repo} to {'private' if private else 'public'}.")
    else:
        logging.error(f"❌ Failed to update {owner}/{repo}: {response.status_code}")
        logging.debug(response.json())

def git_pull(directory):
    logging.info(f"Updating repository in {directory}")
    try:
        # Fetch the latest changes from the remote
        subprocess.run(["git", "fetch", "origin"], cwd=directory, capture_output=True, text=True, check=True)
        logging.info("✔ Git fetch successful.")

        # Get the current branch name
        branch_result = subprocess.run(["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=directory, capture_output=True, text=True, check=True)
        current_branch = branch_result.stdout.strip()

        # Reset the local branch to match the remote, discarding local changes
        reset_result = subprocess.run(["git", "reset", "--hard", f"origin/{current_branch}"], cwd=directory, capture_output=True, text=True, check=True)
        logging.info(f"✔ Git reset to origin/{current_branch} successful.")
        if reset_result.stdout:
            logging.info(reset_result.stdout)

    except subprocess.CalledProcessError as e:
        logging.error("❌ Failed to update git repository.")
        logging.error(f"Command: '{' '.join(e.cmd)}'")
        logging.error(f"Stderr: {e.stderr}")

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    git_pull(script_dir)
    repos_file = os.path.join(script_dir, "repos.yaml")
    repos = load_repos(repos_file)
    for r in repos:
        set_visibility(r["owner"], r["name"], r["private"])

if __name__ == "__main__":
    main()