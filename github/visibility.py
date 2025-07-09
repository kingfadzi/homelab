#!/usr/bin/env python3

import os
import yaml
import requests
import logging
import time

# Setup logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")

# Read GitHub token from environment variable
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
if not GITHUB_TOKEN:
    logging.error("❌ GITHUB_TOKEN environment variable not set.")
    exit(1)

# GitHub API headers
HEADERS = {
    "Authorization": f"token {GITHUB_TOKEN}",
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

def main():
    repos = load_repos("repos.yaml")
    for r in repos:
        set_visibility(r["owner"], r["name"], r["private"])

if __name__ == "__main__":
    main()