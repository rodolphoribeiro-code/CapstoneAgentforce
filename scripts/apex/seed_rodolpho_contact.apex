// Create Contact and bookings for dorfao@gmail.com (Rodolpho Ribeiro)
// Seeded with 6 confirmed bookings → VIP tier
Contact c = new Contact(
    FirstName = 'Rodolpho',
    LastName = 'Ribeiro',
    Email = 'dorfao@gmail.com'
);
insert c;

Restaurant__c elRancho = [SELECT Id FROM Restaurant__c WHERE Name = 'El Rancho' LIMIT 1];
Restaurant__c laBella = [SELECT Id FROM Restaurant__c WHERE Name = 'La Bella Italia' LIMIT 1];

List<Booking__c> bookings = new List<Booking__c>();

// Past bookings (confirmed) — pushes into VIP tier
for (Integer i = 1; i <= 4; i++) {
    bookings.add(new Booking__c(
        Restaurant__c = elRancho.Id,
        Booking_Date__c = DateTime.now().addDays(-i * 30),
        Party_Size__c = 2,
        Customer_Name__c = 'Rodolpho Ribeiro',
        Customer_Email__c = 'dorfao@gmail.com',
        Status__c = 'Confirmed'
    ));
}
bookings.add(new Booking__c(
    Restaurant__c = laBella.Id,
    Booking_Date__c = DateTime.now().addDays(-150),
    Party_Size__c = 4,
    Customer_Name__c = 'Rodolpho Ribeiro',
    Customer_Email__c = 'dorfao@gmail.com',
    Status__c = 'Confirmed'
));

// Upcoming booking to test modify/cancel
bookings.add(new Booking__c(
    Restaurant__c = elRancho.Id,
    Booking_Date__c = DateTime.now().addDays(14),
    Party_Size__c = 2,
    Customer_Name__c = 'Rodolpho Ribeiro',
    Customer_Email__c = 'dorfao@gmail.com',
    Status__c = 'Confirmed',
    Special_Requests__c = 'Window seat please'
));

insert bookings;

List<Booking__c> created = [SELECT Name FROM Booking__c WHERE Customer_Email__c = 'dorfao@gmail.com' ORDER BY CreatedDate];
System.debug('Contact: ' + c.Id);
System.debug('Bookings created: ' + created.size());
for (Booking__c b : created) {
    System.debug(b.Name);
}
