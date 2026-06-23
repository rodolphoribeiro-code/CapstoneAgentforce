// Seed mock data for Intelligent Diner Support Agent

// Clean existing mock data
delete [SELECT Id FROM Booking__c LIMIT 200];
delete [SELECT Id FROM Restaurant__c LIMIT 200];

// Create Restaurants
List<Restaurant__c> restaurants = new List<Restaurant__c>{
    new Restaurant__c(
        Name = 'La Bella Italia',
        Cuisine_Type__c = 'Italian',
        Location__c = '123 Main St, New York, NY 10001',
        Opening_Hours__c = 'Mon-Sun 11:00 AM - 11:00 PM',
        Capacity__c = 80,
        Dietary_Options__c = 'Vegetarian, Gluten-Free, Vegan',
        Phone__c = '(212) 555-0101'
    ),
    new Restaurant__c(
        Name = 'Sakura Garden',
        Cuisine_Type__c = 'Japanese',
        Location__c = '456 Oak Ave, New York, NY 10002',
        Opening_Hours__c = 'Tue-Sun 12:00 PM - 10:00 PM',
        Capacity__c = 60,
        Dietary_Options__c = 'Vegetarian, Vegan',
        Phone__c = '(212) 555-0202'
    ),
    new Restaurant__c(
        Name = 'El Rancho',
        Cuisine_Type__c = 'Mexican',
        Location__c = '789 Elm St, New York, NY 10003',
        Opening_Hours__c = 'Mon-Sun 10:00 AM - 11:00 PM',
        Capacity__c = 100,
        Dietary_Options__c = 'Vegetarian, Gluten-Free',
        Phone__c = '(212) 555-0303'
    ),
    new Restaurant__c(
        Name = 'The Brooklyn Grill',
        Cuisine_Type__c = 'American',
        Location__c = '321 Park Blvd, Brooklyn, NY 11201',
        Opening_Hours__c = 'Mon-Sun 11:00 AM - 12:00 AM',
        Capacity__c = 120,
        Dietary_Options__c = 'Vegetarian, Gluten-Free',
        Phone__c = '(718) 555-0404'
    ),
    new Restaurant__c(
        Name = 'Maison Paris',
        Cuisine_Type__c = 'French',
        Location__c = '555 Upper East Side, New York, NY 10021',
        Opening_Hours__c = 'Tue-Sun 6:00 PM - 11:00 PM',
        Capacity__c = 50,
        Dietary_Options__c = 'Vegetarian',
        Phone__c = '(212) 555-0505'
    )
};
insert restaurants;

System.debug('Created ' + restaurants.size() + ' restaurants.');

// Create Bookings
List<Booking__c> bookings = new List<Booking__c>{
    new Booking__c(
        Restaurant__c = restaurants[0].Id,
        Customer_Name__c = 'John Smith',
        Customer_Email__c = 'john.smith@example.com',
        Booking_Date__c = DateTime.now().addDays(3),
        Party_Size__c = 4,
        Status__c = 'Confirmed',
        Booking_Value__c = 180.00,
        Is_VIP__c = false
    ),
    new Booking__c(
        Restaurant__c = restaurants[1].Id,
        Customer_Name__c = 'Maria Garcia',
        Customer_Email__c = 'maria.garcia@example.com',
        Booking_Date__c = DateTime.now().addDays(1),
        Party_Size__c = 2,
        Status__c = 'Confirmed',
        Booking_Value__c = 95.00,
        Is_VIP__c = false
    ),
    new Booking__c(
        Restaurant__c = restaurants[3].Id,
        Customer_Name__c = 'Platinum VIP Guest',
        Customer_Email__c = 'vip@example.com',
        Booking_Date__c = DateTime.now().addDays(2),
        Party_Size__c = 6,
        Status__c = 'Confirmed',
        Booking_Value__c = 620.00,
        Is_VIP__c = true,
        Special_Requests__c = 'Anniversary dinner. Please prepare special dessert.'
    ),
    new Booking__c(
        Restaurant__c = restaurants[2].Id,
        Customer_Name__c = 'Bob Johnson',
        Customer_Email__c = 'bob.johnson@example.com',
        Booking_Date__c = DateTime.now().addDays(5),
        Party_Size__c = 3,
        Status__c = 'Confirmed',
        Booking_Value__c = 120.00,
        Is_VIP__c = false
    ),
    new Booking__c(
        Restaurant__c = restaurants[4].Id,
        Customer_Name__c = 'Alice Chen',
        Customer_Email__c = 'alice.chen@example.com',
        Booking_Date__c = DateTime.now().addDays(7),
        Party_Size__c = 2,
        Status__c = 'Confirmed',
        Booking_Value__c = 210.00,
        Is_VIP__c = false,
        Special_Requests__c = 'Window table preferred.'
    )
};
insert bookings;

System.debug('Created ' + bookings.size() + ' bookings.');
System.debug('');
System.debug('=== BOOKING IDs (use these to test the agent) ===');
for (Booking__c b : [SELECT Id, Name, Customer_Name__c, Restaurant__r.Name, Status__c FROM Booking__c ORDER BY Name]) {
    System.debug(b.Name + ' | ' + b.Customer_Name__c + ' | ' + b.Restaurant__r.Name + ' | ' + b.Status__c + ' | ID: ' + b.Id);
}
System.debug('=== RESTAURANT IDs ===');
for (Restaurant__c r : [SELECT Id, Name, Cuisine_Type__c FROM Restaurant__c ORDER BY Name]) {
    System.debug(r.Name + ' | ' + r.Cuisine_Type__c + ' | ID: ' + r.Id);
}
