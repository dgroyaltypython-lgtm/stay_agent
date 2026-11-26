from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .api_views import AgentBookingListView, AgentBookingStatusView, AgentTokenView

urlpatterns = [
    path("api/agent/token/", AgentTokenView.as_view(), name="agent-token"),
    path("api/agent/token/refresh/", TokenRefreshView.as_view(), name="agent-token-refresh"),
    path("api/agent/bookings/", AgentBookingListView.as_view(), name="agent-bookings"),
    path("api/agent/bookings/<int:pk>/status/", AgentBookingStatusView.as_view(), name="agent-booking-status"),
]
