// Seed 15 global restaurants across major cities
// All are part of The Diner international expansion

List<Restaurant__c> restaurants = new List<Restaurant__c>{

    // ── SAN FRANCISCO ──
    new Restaurant__c(
        Name = 'The Golden Gate Bistro',
        Cuisine_Type__c = 'American',
        Location__c = '1 Ferry Building, Embarcadero, San Francisco, CA 94111',
        Opening_Hours__c = 'Mon-Sun 11:00 AM - 11:00 PM',
        Capacity__c = 90,
        Dietary_Options__c = 'Vegetarian, Vegan, Gluten-Free',
        Phone__c = '(415) 555-0101'
    ),
    new Restaurant__c(
        Name = 'Mission Taqueria',
        Cuisine_Type__c = 'Mexican',
        Location__c = '2500 Mission St, Mission District, San Francisco, CA 94110',
        Opening_Hours__c = 'Mon-Sun 10:00 AM - 11:00 PM',
        Capacity__c = 75,
        Dietary_Options__c = 'Vegetarian, Vegan, Gluten-Free',
        Phone__c = '(415) 555-0202'
    ),
    new Restaurant__c(
        Name = 'Nob Hill Sushi',
        Cuisine_Type__c = 'Japanese',
        Location__c = '1100 California St, Nob Hill, San Francisco, CA 94108',
        Opening_Hours__c = 'Tue-Sun 12:00 PM - 10:00 PM',
        Capacity__c = 55,
        Dietary_Options__c = 'Vegetarian, Vegan',
        Phone__c = '(415) 555-0303'
    ),

    // ── LOS ANGELES ──
    new Restaurant__c(
        Name = 'Sunset Strip Kitchen',
        Cuisine_Type__c = 'American',
        Location__c = '8752 Sunset Blvd, West Hollywood, Los Angeles, CA 90069',
        Opening_Hours__c = 'Mon-Sun 11:00 AM - 12:00 AM',
        Capacity__c = 110,
        Dietary_Options__c = 'Vegetarian, Vegan, Gluten-Free',
        Phone__c = '(310) 555-0101'
    ),
    new Restaurant__c(
        Name = 'Venice Beach Grill',
        Cuisine_Type__c = 'Mediterranean',
        Location__c = '30 Windward Ave, Venice Beach, Los Angeles, CA 90291',
        Opening_Hours__c = 'Mon-Sun 9:00 AM - 10:00 PM',
        Capacity__c = 85,
        Dietary_Options__c = 'Vegetarian, Vegan, Gluten-Free',
        Phone__c = '(310) 555-0202'
    ),

    // ── CHICAGO ──
    new Restaurant__c(
        Name = 'Deep Dish House',
        Cuisine_Type__c = 'American',
        Location__c = '14 W Randolph St, Loop, Chicago, IL 60601',
        Opening_Hours__c = 'Mon-Sun 11:00 AM - 11:00 PM',
        Capacity__c = 100,
        Dietary_Options__c = 'Vegetarian, Gluten-Free',
        Phone__c = '(312) 555-0101'
    ),
    new Restaurant__c(
        Name = 'Wicker Park Ramen',
        Cuisine_Type__c = 'Japanese',
        Location__c = '2001 W North Ave, Wicker Park, Chicago, IL 60647',
        Opening_Hours__c = 'Tue-Sun 11:30 AM - 10:00 PM',
        Capacity__c = 60,
        Dietary_Options__c = 'Vegetarian, Vegan',
        Phone__c = '(312) 555-0202'
    ),

    // ── MIAMI ──
    new Restaurant__c(
        Name = 'South Beach Ceviche',
        Cuisine_Type__c = 'Latin American',
        Location__c = '1500 Ocean Dr, South Beach, Miami Beach, FL 33139',
        Opening_Hours__c = 'Mon-Sun 12:00 PM - 11:00 PM',
        Capacity__c = 80,
        Dietary_Options__c = 'Vegetarian, Gluten-Free',
        Phone__c = '(305) 555-0101'
    ),
    new Restaurant__c(
        Name = 'Wynwood Tap House',
        Cuisine_Type__c = 'American',
        Location__c = '2500 NW 2nd Ave, Wynwood, Miami, FL 33127',
        Opening_Hours__c = 'Wed-Sun 5:00 PM - 12:00 AM',
        Capacity__c = 95,
        Dietary_Options__c = 'Vegetarian, Vegan, Gluten-Free',
        Phone__c = '(305) 555-0202'
    ),

    // ── LONDON ──
    new Restaurant__c(
        Name = 'Borough Market Table',
        Cuisine_Type__c = 'British',
        Location__c = '8 Southwark St, Borough Market, London SE1 1TL, UK',
        Opening_Hours__c = 'Mon-Sat 11:00 AM - 10:00 PM',
        Capacity__c = 70,
        Dietary_Options__c = 'Vegetarian, Vegan, Gluten-Free',
        Phone__c = '+44 20 7946 0101'
    ),
    new Restaurant__c(
        Name = 'Shoreditch Curry House',
        Cuisine_Type__c = 'Indian',
        Location__c = '45 Curtain Rd, Shoreditch, London EC2A 3PT, UK',
        Opening_Hours__c = 'Mon-Sun 12:00 PM - 11:00 PM',
        Capacity__c = 65,
        Dietary_Options__c = 'Vegetarian, Vegan, Gluten-Free, Halal',
        Phone__c = '+44 20 7946 0202'
    ),

    // ── PARIS ──
    new Restaurant__c(
        Name = 'Le Marais Bistrot',
        Cuisine_Type__c = 'French',
        Location__c = '25 Rue de Bretagne, Le Marais, Paris 75003, France',
        Opening_Hours__c = 'Tue-Sun 12:00 PM - 11:00 PM',
        Capacity__c = 55,
        Dietary_Options__c = 'Vegetarian',
        Phone__c = '+33 1 42 72 0101'
    ),
    new Restaurant__c(
        Name = 'Montmartre Wine Bar',
        Cuisine_Type__c = 'French',
        Location__c = '12 Rue Lepic, Montmartre, Paris 75018, France',
        Opening_Hours__c = 'Wed-Mon 5:00 PM - 12:00 AM',
        Capacity__c = 45,
        Dietary_Options__c = 'Vegetarian, Gluten-Free',
        Phone__c = '+33 1 42 54 0202'
    ),

    // ── SAO PAULO ──
    new Restaurant__c(
        Name = 'Vila Madalena Churrasco',
        Cuisine_Type__c = 'Brazilian',
        Location__c = 'Rua Aspicuelta 200, Vila Madalena, Sao Paulo - SP 05433-010, Brazil',
        Opening_Hours__c = 'Mon-Sun 12:00 PM - 11:00 PM',
        Capacity__c = 120,
        Dietary_Options__c = 'Gluten-Free',
        Phone__c = '+55 11 3813-0101'
    ),
    new Restaurant__c(
        Name = 'Jardins Fusion',
        Cuisine_Type__c = 'Contemporary Brazilian',
        Location__c = 'Rua Oscar Freire 900, Jardins, Sao Paulo - SP 01426-001, Brazil',
        Opening_Hours__c = 'Tue-Sun 12:00 PM - 11:00 PM',
        Capacity__c = 70,
        Dietary_Options__c = 'Vegetarian, Vegan, Gluten-Free',
        Phone__c = '+55 11 3062-0202'
    )
};

insert restaurants;
System.debug('Inserted ' + restaurants.size() + ' global restaurants');
for (Restaurant__c r : restaurants) {
    System.debug(r.Name + ' | ' + r.Location__c);
}
