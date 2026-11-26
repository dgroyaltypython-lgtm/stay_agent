from rest_framework import serializers
from .models import Booking

class AgentBookingSerializer(serializers.ModelSerializer):
    property_name = serializers.CharField(source="property.name", read_only=True)
    room_type_name = serializers.CharField(source="room_type.name", read_only=True, allow_null=True)

    class Meta:
        model = Booking
        fields = [
            "id", "reference", "customer_name", "customer_phone",
            "property", "property_name", "room_type", "room_type_name",
            "check_in", "check_out", "guests", "total_amount",
            "status", "notes", "created_at",
        ]
        read_only_fields = fields
