export const handler = async (event) => {
  const clientId = event.callerContext.clientId;
  event.response = {
    claimsAndScopeOverrideDetails: {
      accessTokenGeneration: {
        claimsToAddOrOverride: {
          env: process.env.ENVIRONMENT || "production",
          name: clientId,
          preferred_username: clientId,
          idp: "cognito",
          resources: [{ resource_id: "urc-*", permission: [] }],
        },
      },
    },
  };
  return event;
};
