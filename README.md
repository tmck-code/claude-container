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
        -v $HOME/.claude.json:/home/claude/.claude.json \
        -v $HOME/.claude/:/home/claude/.claude/ \
        -v $PWD/pyproject.toml:/app/pyproject.toml \
        -v $PWD/uv.lock:/app/uv.lock \
        -v $PWD/my-code-dir:/app/my-code-dir \ # <-- replace with your code dir
        claude-code \
        bash -c 'claude --dangerously-skip-permissions'
    ```
