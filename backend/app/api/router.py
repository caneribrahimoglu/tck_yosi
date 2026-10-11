from fastapi import APIRouter

from app.api.routes.auth import router as auth_router
from app.api.routes.management import router as management_router
from app.api.routes.technical_work import router as technical_work_router


api_router = APIRouter(prefix="/api/v1")
api_router.include_router(auth_router)
api_router.include_router(management_router)
api_router.include_router(technical_work_router)
