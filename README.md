# claude-container

Run Claude Code safely in a containerized environment.

## Commands

- build the Docker image:
    ```shell
    docker build -t claude-code .
    ```
- run container, bind-mounting the current directory to `/app` in the container:
    ```shell
    docker run -it -v $PWD:/app claude-code claude
    ```
