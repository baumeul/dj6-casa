from django.contrib import admin

from .models import Apartment, Booking, Guest, Portal, Service, Status

admin.site.register(Portal)
admin.site.register(Status)


@admin.register(Apartment)
class ApartmentAdmin(admin.ModelAdmin):
    list_display = ["apartment_name", "short_name"]


@admin.register(Guest)
class GuestAdmin(admin.ModelAdmin):
    list_display = ["first_name", "last_name", "title"]
    list_filter = ["title"]
    search_fields = ["first_name", "last_name", "title"]


@admin.register(Service)
class ServiceAdmin(admin.ModelAdmin):
    list_display = [
        "category",
        "service_name",
        "price",
        "unit",
        "is_active",
        "is_default",
    ]
    list_filter = [
        "category",
        "unit",
        "is_active",
        "is_default",
    ]
    search_fields = [
        "category",
        "service_name",
        "unit",
    ]


@admin.register(Booking)
class Booking(admin.ModelAdmin):
    list_display = [
        "apartment",
        "guest",
        "check_in",
        "check_out",
        "price",
        "number_guests",
    ]
    list_filter = ["apartment", "check_in", "check_out"]
    search_fields = [
        "check_in",
        "check_out",
        "number_guests",
        "apartment__apartment_name",
    ]
