"""Hello-world API. Deliberately tiny: the environment around it is the real project."""

from fastapi import FastAPI

app = FastAPI(title="hello-platform", version="0.1.0")


@app.get("/")
def hello() -> dict[str, str]:
    """Main endpoint: proves the app is running."""
    return {"message": "Pipeline testing. testing main branch protection"}


@app.get("/health")
def health() -> dict[str, str]:
    """Health check. Docker and Kubernetes will call this to know if the app is alive."""
    return {"status": "ok"}
