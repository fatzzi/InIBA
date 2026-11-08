"""Standard error model from the API doc (1.3): every non-2xx body is {"code": int, "message": str}."""

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException


def _body(code: int, message: str) -> JSONResponse:
    return JSONResponse(status_code=code, content={"code": code, "message": message})


def install_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(StarletteHTTPException)
    async def http_error(_: Request, exc: StarletteHTTPException) -> JSONResponse:
        return _body(exc.status_code, str(exc.detail))

    @app.exception_handler(RequestValidationError)
    async def validation_error(_: Request, exc: RequestValidationError) -> JSONResponse:
        first = exc.errors()[0] if exc.errors() else {}
        field = ".".join(str(p) for p in first.get("loc", []) if p != "body")
        return _body(400, f"Invalid input{': ' + field if field else ''}: {first.get('msg', 'bad request')}")


__all__ = ["install_error_handlers", "HTTPException"]
