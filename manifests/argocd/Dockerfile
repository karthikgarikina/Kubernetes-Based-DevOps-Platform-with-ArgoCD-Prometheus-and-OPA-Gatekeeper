FROM alpine:3.20
RUN apk add --no-cache git git-daemon
EXPOSE 9418
CMD ["sh", "-c", "mkdir -p /git/repo.git && git init --bare /git/repo.git && git -C /git/repo.git symbolic-ref HEAD refs/heads/main && git -C /git/repo.git config daemon.receivepack true && git -C /git/repo.git config receive.denyCurrentBranch ignore && exec git daemon --verbose --export-all --base-path=/git --enable=receive-pack --reuseaddr"]
