################################################
from datetime import timedelta

from django.core.exceptions import ValidationError
from django.db import models
from django.utils import timezone


def default_check_in():
    return timezone.localdate()


def default_check_out():
    return timezone.localdate() + timedelta(days=1)


class Booking(models.Model):
    class CreatedBy(models.TextChoices):
        ADMIN = "ADMIN", "Admin"
        BIRGIT = "BIRGIT", "Birgit"

    class UpdatedBy(models.TextChoices):
        ADMIN = "ADMIN", "Admin"
        BIRGIT = "BIRGIT", "Birgit"

    guest = models.ForeignKey(
        "Guest", on_delete=models.DO_NOTHING, null=True, blank=True
    )
    apartment = models.ForeignKey(
        "Apartment", on_delete=models.DO_NOTHING, null=True, blank=True
    )

    check_in = models.DateField(default=default_check_in)
    check_out = models.DateField(default=default_check_out)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    number_guests = models.IntegerField(default=1)
    created_at = models.DateTimeField(auto_now_add=True, null=True, blank=True)
    created_by = models.CharField(
        max_length=100,
        null=True,
        blank=True,
        choices=CreatedBy,
        default=CreatedBy.BIRGIT,
    )
    updated_at = models.DateTimeField(auto_now=True, null=True, blank=True)
    updated_by = models.CharField(
        max_length=100,
        null=True,
        blank=True,
        choices=UpdatedBy,
        default=UpdatedBy.BIRGIT,
    )

    def __str__(self) -> str:
        return f"{self.check_in} - {self.check_out}"

    class Meta:
        db_table = "ca_bookings"
        ordering = ["-check_in"]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(check_out__gt=models.F("check_in")),
                name="booking_check_out_after_check_in",
            ),
        ]

    def clean(self):
        if self.check_in and self.check_out and self.check_out <= self.check_in:
            raise ValidationError("Das Abreisedatum muss nach dem Anreisedatum liegen.")


class Apartment(models.Model):
    apartment_name = models.CharField(max_length=200)
    short_name = models.CharField(max_length=3, null=True, blank=True)

    def __str__(self) -> str:
        return self.apartment_name

    class Meta:
        db_table = "ca_apartments"


class Guest(models.Model):
    first_name = models.CharField(max_length=200, null=True, blank=True)
    last_name = models.CharField(max_length=200, null=True, blank=True)
    title = models.CharField(max_length=200, null=True, blank=True)

    def __str__(self) -> str:
        return f"{self.first_name} {self.last_name}"

    class Meta:
        db_table = "ca_guests"
        ordering = ["last_name"]


class Portal(models.Model):
    portal_name = models.CharField(max_length=200)
    portal_url = models.CharField(max_length=200, null=True, blank=True)
    portal_user = models.CharField(max_length=200, null=True, blank=True)
    portal_password = models.CharField(max_length=200, null=True, blank=True)

    def __str__(self) -> str:
        return f"{self.portal_name}"

    class Meta:
        db_table = "ca_portals"


class Status(models.Model):
    status_name_de = models.CharField(max_length=200)
    status_name_it = models.CharField(max_length=200, null=True, blank=True)

    def __str__(self) -> str:
        return f"{self.status_name_de}"

    class Meta:
        db_table = "ca_statuses"


class Service(models.Model):
    class ActiveStatus(models.TextChoices):
        YES = "Y", "Yes"
        NO = "N", "No"

    class DefaultStatus(models.TextChoices):
        NO = "N", "No"
        CPV = "V", "CPV"
        CPG = "G", "CPG"

    class Unit(models.TextChoices):
        STUECK = "STÜCK", "Stück"
        PAUSCHAL = "PAUSCHAL", "Pauschal"

    category = models.CharField(max_length=200)
    service_name = models.CharField(max_length=200)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    unit = models.CharField(max_length=100, choices=Unit, default=Unit.STUECK)
    is_active = models.CharField(
        max_length=1, choices=ActiveStatus, default=ActiveStatus.NO
    )
    is_default = models.CharField(
        max_length=1, choices=DefaultStatus, default=DefaultStatus.NO
    )

    def __str__(self) -> str:
        return f"{self.category}/{self.service_name}"

    class Meta:
        db_table = "ca_services"
