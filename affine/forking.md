1. **Fork the Repository**:
    - Visit the upstream repository on GitHub: [https://github.com/toeverything/AFFiNE.git](https://github.com/toeverything/AFFiNE.git)
    - Click on the "Fork" button at the top right of the page to fork the repository to your GitHub account.

2. **Clone Your Fork**:
    - After forking, clone your fork to your local machine:
      ```bash
      git clone https://github.com/yourusername/AFFiNE.git
      cd AFFiNE
      ```

3. **Add the Upstream Remote**:
    - Add the original repository as an upstream remote to your local clone:
      ```bash
      git remote add upstream https://github.com/toeverything/AFFiNE.git
      ```

4. **Fetch Tags from Upstream**:
    - Fetch all tags from the upstream repository:
      ```bash
      git fetch upstream --tags
      ```

5. **Checkout the Tag**:
    - Checkout the specific tag you are interested in, e.g., `v0.17.0-canary.3`:
      ```bash
      git checkout tags/v0.17.0-canary.3
      ```

6. **Create a New Branch from the Tag**:
    - Create a new branch from this tag to start your work:
      ```bash
      git checkout -b v0.17.0-canary.3-fork
      ```

7. **Push the New Branch to Your Fork**:
    - Push the new branch to your fork on GitHub:
      ```bash
      git push origin v0.17.0-canary.3-fork
      ```
