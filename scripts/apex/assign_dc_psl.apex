// Assign GenieDataPlatformStarterPsl to the Einstein Agent User
// Required for AnswerQuestionsWithKnowledge (ADL grounding)
User agentUser = [SELECT Id FROM User WHERE Profile.UserLicense.Name = 'Einstein Agent' AND IsActive = true AND Username LIKE '%orgfarm%' LIMIT 1];
PermissionSetLicense psl = [SELECT Id FROM PermissionSetLicense WHERE DeveloperName = 'GenieDataPlatformStarterPsl' LIMIT 1];

List<PermissionSetLicenseAssign> existing = [
    SELECT Id FROM PermissionSetLicenseAssign
    WHERE AssigneeId = :agentUser.Id AND PermissionSetLicenseId = :psl.Id LIMIT 1
];
if (existing.isEmpty()) {
    insert new PermissionSetLicenseAssign(AssigneeId = agentUser.Id, PermissionSetLicenseId = psl.Id);
    System.debug('SUCCESS: GenieDataPlatformStarterPsl assigned to ' + agentUser.Id);
} else {
    System.debug('ALREADY ASSIGNED: GenieDataPlatformStarterPsl was already assigned');
}
