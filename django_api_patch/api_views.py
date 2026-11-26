from django.db.models import Q
from rest_framework import generics, serializers, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework_simplejwt.views import TokenObtainPairView

from accounts.models import User
from core.models import Booking
from .api_serializers import AgentBookingSerializer


class AgentRolePermission(IsAuthenticated):
    def has_permission(self, request, view):
        return bool(
            super().has_permission(request, view)
            and request.user.is_authenticated
            and request.user.role in (User.Role.AGENT, User.Role.ADMIN)
        )


class AgentTokenSerializer(TokenObtainPairSerializer):
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token["role"] = user.role
        return token

    def validate(self, attrs):
        data = super().validate(attrs)
        if self.user.role not in (User.Role.AGENT, User.Role.ADMIN):
            raise serializers.ValidationError({"detail": "This account is not enabled for the Agent app."})
        data["user"] = {
            "id": self.user.pk,
            "username": self.user.get_username(),
            "name": self.user.get_full_name() or self.user.get_username(),
            "role": self.user.role,
        }
        return data


class AgentTokenView(TokenObtainPairView):
    serializer_class = AgentTokenSerializer


class AgentBookingListView(generics.ListAPIView):
    permission_classes = [AgentRolePermission]
    serializer_class = AgentBookingSerializer

    def get_queryset(self):
        qs = Booking.objects.select_related("property", "room_type").all()
        selected_status = self.request.query_params.get("status")
        search = self.request.query_params.get("q", "").strip()
        if selected_status:
            qs = qs.filter(status=selected_status)
        if search:
            qs = qs.filter(
                Q(reference__icontains=search)
                | Q(customer_name__icontains=search)
                | Q(customer_phone__icontains=search)
                | Q(property__name__icontains=search)
            )
        return qs.order_by("-created_at")


class AgentBookingStatusView(APIView):
    permission_classes = [AgentRolePermission]
    transitions = {
        Booking.Status.ENQUIRY: {Booking.Status.CONFIRMED, Booking.Status.CANCELLED},
        Booking.Status.CONFIRMED: {Booking.Status.CHECKED_IN, Booking.Status.CANCELLED},
        Booking.Status.CHECKED_IN: {Booking.Status.COMPLETED},
        Booking.Status.COMPLETED: set(),
        Booking.Status.CANCELLED: set(),
    }

    def patch(self, request, pk):
        try:
            booking = Booking.objects.select_related("property", "room_type").get(pk=pk)
        except Booking.DoesNotExist:
            return Response({"detail": "Booking not found."}, status=status.HTTP_404_NOT_FOUND)
        new_status = request.data.get("status")
        if new_status not in Booking.Status.values:
            return Response({"detail": "Invalid booking status."}, status=status.HTTP_400_BAD_REQUEST)
        if new_status not in self.transitions.get(booking.status, set()):
            return Response({"detail": f"Status cannot change from {booking.status} to {new_status}."}, status=status.HTTP_400_BAD_REQUEST)
        booking.status = new_status
        booking.save(update_fields=["status"])
        return Response(AgentBookingSerializer(booking).data)
