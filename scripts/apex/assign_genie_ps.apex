// Assign GenieUserEnhancedSecurity PS to the Einstein Agent User
// This grants Data Cloud access compatible with the Einstein Agent license
User agentUser = [
    SELECT Id FROM User
    WHERE Profile.UserLicense.Name = 'Einstein Agent'
    AND IsActive = true
    AND Username LIKE '%orgfarm%'
    LIMIT 1
];
PermissionSet ps = [
    SELECT Id FROM PermissionSet
    WHERE Name = 'GenieUserEnhancedSecurity'
    LIMIT 1
];

List<PermissionSetAssignment> existing = [
    SELECT Id FROM PermissionSetAssignment
    WHERE AssigneeId = :agentUser.Id AND PermissionSetId = :ps.Id LIMIT 1
];
if (existing.isEmpty()) {
    insert new PermissionSetAssignment(AssigneeId = agentUser.Id, PermissionSetId = ps.Id);
    System.debug('SUCCESS: GenieUserEnhancedSecurity assigned to ' + agentUser.Id);
} else {
    System.debug('ALREADY ASSIGNED');
}
