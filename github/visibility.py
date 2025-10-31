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
    logging.info(f"Running git pull in {directory}")
    result = subprocess.run(["git", "pull"], cwd=directory, capture_output=True, text=True)
    if result.returncode == 0:
        logging.info("✔ Git pull successful.")
        logging.info(result.stdout)
    else:
        logging.error("❌ Git pull failed.")
        logging.error(result.stderr)

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    git_pull(script_dir)
    repos_file = os.path.join(script_dir, "repos.yaml")
    repos = load_repos(repos_file)
    for r in repos:
        set_visibility(r["owner"], r["name"], r["private"])

if __name__ == "__main__":
    main()