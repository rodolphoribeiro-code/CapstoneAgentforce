// Seed 5 confirmed bookings for john.smith@example.com at El Rancho
// This pushes John Smith past the VIP threshold (5+ confirmed bookings)
Restaurant__c elRancho = [SELECT Id FROM Restaurant__c WHERE Name = 'El Rancho' LIMIT 1];

List<Booking__c> bookings = new List<Booking__c>();
for (Integer i = 1; i <= 5; i++) {
    bookings.add(new Booking__c(
        Restaurant__c = elRancho.Id,
        Booking_Date__c = DateTime.now().addDays(-i * 30),
        Party_Size__c = 2,
        Customer_Name__c = 'John Smith',
        Customer_Email__c = 'john.smith@example.com',
        Status__c = 'Confirmed'
    ));
}
insert bookings;
System.debug('Inserted ' + bookings.size() + ' VIP seed bookings for John Smith');
