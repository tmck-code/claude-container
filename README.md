# claude-container

Run Claude Code safely in a containerized environment.

## Commands

- build the Docker image:
    ```shell
    docker build -t claude-code .
    ```
- run container
    - bind-mounting the current directory and
    - your Claude credentials, to avoid re-auth on every run
    ```shell
    docker run -it \
      -v $PWD:/app \
      -v $HOME/.claude.json:/home/claude/.claude.json \
      claude-code claude
    ```
    The `~/.claude` mount reuses your existing authentication so you don't have to log in on every run.
