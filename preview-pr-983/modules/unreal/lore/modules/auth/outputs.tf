output "user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.lore.id
}

output "client_id" {
  description = "Cognito app client ID"
  value       = aws_cognito_user_pool_client.lore.id
}

output "client_secret" {
  description = "Cognito app client secret"
  value       = aws_cognito_user_pool_client.lore.client_secret
  sensitive   = true
}

output "token_endpoint" {
  description = "OAuth2 token endpoint"
  value       = "https://${aws_cognito_user_pool_domain.lore.domain}.auth.${data.aws_region.current.name}.amazoncognito.com/oauth2/token"
}

output "jwk_endpoint" {
  description = "JWK endpoint for JWT validation"
  value       = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.lore.id}/.well-known/jwks.json"
}

output "issuer" {
  description = "JWT issuer URL"
  value       = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.lore.id}"
}
