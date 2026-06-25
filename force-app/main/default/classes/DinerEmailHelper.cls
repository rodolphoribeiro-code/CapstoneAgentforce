public without sharing class DinerEmailHelper {

    static OrgWideEmailAddress getOwa() {
        List<OrgWideEmailAddress> owas = [SELECT Id FROM OrgWideEmailAddress WHERE DisplayName = 'The Diner' LIMIT 1];
        if (owas.isEmpty()) owas = [SELECT Id FROM OrgWideEmailAddress LIMIT 1];
        return owas.isEmpty() ? null : owas[0];
    }

    static String baseHeader(String subtitle) {
        return '<div style="font-family:Arial,sans-serif;max-width:520px;margin:0 auto">' +
               '<div style="background:#1a1a1a;padding:24px;text-align:center">' +
               '<h1 style="color:#c8a96e;margin:0;font-size:1.4rem">The Diner</h1>' +
               '<p style="color:rgba(255,255,255,.6);margin:.4rem 0 0;font-size:.85rem">' + subtitle + '</p>' +
               '</div>' +
               '<div style="padding:28px;border:1px solid #e8e0d0;border-top:none">';
    }

    static String baseFooter() {
        return '</div>' +
               '<div style="background:#f7f5f0;padding:14px;text-align:center;font-size:.75rem;color:#999">' +
               'The Diner Restaurant Group — See you soon! 🍽️</div>' +
               '</div>';
    }

    static String tableRow(String label, String value) {
        return '<tr style="border-bottom:1px solid #f0e8d8">' +
               '<td style="padding:.6rem 0;color:#888;width:120px">' + label + '</td>' +
               '<td style="padding:.6rem 0;color:#1a1a1a">' + value + '</td></tr>';
    }

    public static Boolean sendBookingConfirmation(String toEmail, String customerName, String bookingNumber,
                                                   String restaurantName, String dateStr, String timeStr,
                                                   Integer partySize, String specialRequests) {
        if (String.isBlank(toEmail)) return false;
        OrgWideEmailAddress owa = getOwa();
        if (owa == null) return false;
        try {
            String firstName = customerName != null ? customerName.split(' ')[0] : 'there';
            String body = baseHeader('Your reservation is confirmed 🎉') +
                '<h2 style="color:#1a1a1a;margin:0 0 1.2rem;font-size:1.1rem">Hi ' + firstName + '!</h2>' +
                '<p style="color:#555;margin-bottom:1.5rem">We have your table ready. Here are your booking details:</p>' +
                '<table style="width:100%;border-collapse:collapse;font-size:.9rem">' +
                tableRow('Booking #', '<strong>' + bookingNumber + '</strong>') +
                tableRow('Restaurant', restaurantName) +
                tableRow('Date', dateStr) +
                tableRow('Time', timeStr) +
                tableRow('Party size', partySize + ' guest' + (partySize > 1 ? 's' : '')) +
                (String.isNotBlank(specialRequests) ? tableRow('Special requests', specialRequests) : '') +
                '</table>' +
                '<div style="background:#f7f5f0;border-radius:8px;padding:14px 16px;margin-top:1.5rem">' +
                '<p style="margin:0;font-size:.82rem;color:#666">Need to change or cancel? Chat with <strong>Aria</strong> anytime — free cancellation up to 24 hours before your booking.</p>' +
                '</div>' +
                baseFooter();
            return send(toEmail, owa, 'Booking Confirmed — ' + restaurantName + ' (' + bookingNumber + ')', body);
        } catch (Exception e) {
            System.debug('sendBookingConfirmation error: ' + e.getMessage());
            return false;
        }
    }

    public static Boolean sendBookingModification(String toEmail, String bookingNumber, String restaurantName,
                                                   String dateStr, String timeStr, Integer partySize) {
        if (String.isBlank(toEmail)) return false;
        OrgWideEmailAddress owa = getOwa();
        if (owa == null) return false;
        try {
            String body = baseHeader('Your reservation has been updated ✏️') +
                '<p style="color:#555;margin-bottom:1.5rem">Your booking details have been updated. Here\'s what\'s confirmed:</p>' +
                '<table style="width:100%;border-collapse:collapse;font-size:.9rem">' +
                tableRow('Booking #', '<strong>' + bookingNumber + '</strong>') +
                tableRow('Restaurant', restaurantName) +
                tableRow('New Date', dateStr) +
                tableRow('New Time', timeStr) +
                tableRow('Party size', partySize + ' guest' + (partySize > 1 ? 's' : '')) +
                '</table>' +
                '<div style="background:#f7f5f0;border-radius:8px;padding:14px 16px;margin-top:1.5rem">' +
                '<p style="margin:0;font-size:.82rem;color:#666">Need to make further changes? Chat with <strong>Aria</strong> anytime.</p>' +
                '</div>' +
                baseFooter();
            return send(toEmail, owa, 'Booking Updated — ' + restaurantName + ' (' + bookingNumber + ')', body);
        } catch (Exception e) {
            System.debug('sendBookingModification error: ' + e.getMessage());
            return false;
        }
    }

    public static Boolean sendBookingCancellation(String toEmail, String bookingNumber, String restaurantName,
                                                   String dateStr, String timeStr, Integer partySize) {
        if (String.isBlank(toEmail)) return false;
        OrgWideEmailAddress owa = getOwa();
        if (owa == null) return false;
        try {
            String body = baseHeader('Your reservation has been cancelled ❌') +
                '<p style="color:#555;margin-bottom:1.5rem">Your booking has been successfully cancelled. Here are the details:</p>' +
                '<table style="width:100%;border-collapse:collapse;font-size:.9rem">' +
                tableRow('Booking #', '<strong>' + bookingNumber + '</strong>') +
                tableRow('Restaurant', restaurantName) +
                tableRow('Date', dateStr) +
                tableRow('Time', timeStr) +
                tableRow('Party size', partySize + ' guest' + (partySize > 1 ? 's' : '')) +
                '</table>' +
                '<div style="background:#f7f5f0;border-radius:8px;padding:14px 16px;margin-top:1.5rem">' +
                '<p style="margin:0;font-size:.82rem;color:#666">Want to make a new reservation? Chat with <strong>Aria</strong> anytime.</p>' +
                '</div>' +
                baseFooter();
            return send(toEmail, owa, 'Booking Cancelled — ' + restaurantName + ' (' + bookingNumber + ')', body);
        } catch (Exception e) {
            System.debug('sendBookingCancellation error: ' + e.getMessage());
            return false;
        }
    }

    static Boolean send(String toEmail, OrgWideEmailAddress owa, String subject, String htmlBody) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ toEmail });
        mail.setOrgWideEmailAddressId(owa.Id);
        mail.setSubject(subject);
        mail.setHtmlBody(htmlBody);
        Messaging.SendEmailResult[] results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        return results[0].isSuccess();
    }
}
