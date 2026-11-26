# Django API patch for Serein Agent

The Flutter app builds in demo mode now. To connect it to the existing Serein Django portal, copy `api_serializers.py`, `api_views.py`, and `api_urls.py` into the project's `core/` folder.

In `config/urls.py`, add:
```python
from core.api_urls import urlpatterns as agent_api_urlpatterns
urlpatterns += agent_api_urlpatterns
```
Keep the existing `urlpatterns` and existing web/admin routes. Add the import after the existing imports and append after the existing list declaration.

The project requirements already include Django REST Framework and SimpleJWT. If needed:
```powershell
pip install djangorestframework djangorestframework-simplejwt
```

Create an Agent user in Django admin (`/django-admin/`) and set `role` to `AGENT`. `ADMIN` users can also log in.

Run:
```powershell
python manage.py check
python manage.py migrate
python manage.py runserver
```

Set Codemagic variable `API_BASE_URL` to the public HTTPS domain (no trailing slash).

Security scope: this initial API permits authenticated AGENT and ADMIN users to see all bookings because the current Booking model has no assigned-agent field. Before production use by multiple agents, add `assigned_agent = ForeignKey(settings.AUTH_USER_MODEL, ...)`, assign each booking, and scope the queryset and status update to that agent. Do not expose guest records over public HTTP.
