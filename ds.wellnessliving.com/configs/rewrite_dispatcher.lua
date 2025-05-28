-- /etc/nginx/lua/global-functions/rewrite_dispatcher.lua

-- #####################################################################
-- Helper Functions
-- #####################################################################

--[[
  Performs a redirect with logging and setting custom headers.
  @param log_context (string) Context for the log message (e.g., "1st current_host").
  @param target_host_val (string) Host to redirect to.
  @param target_path_val (string) Path to redirect to.
  @param query_prefix_val (string) Prefix for the query string ("?" or the value of ngx.var.is_args).
  @param args_string_val (string) Query string (ngx.var.args).
  @param status_code (number) HTTP status code for the redirect (e.g., 301, 302).
  @param header_host_key (string, optional) Header key for the redirect host. Defaults to "X-Map-WL-Target-Host".
  @param header_path_key (string, optional) Header key for the redirect path. Defaults to "X-Map-WL-Target-Path".
--]]
local function perform_redirect(log_context, target_host_val, target_path_val, query_prefix_val, args_string_val, status_code, header_host_key, header_path_key)
  local redirect_url = "https://" .. target_host_val .. target_path_val .. query_prefix_val .. args_string_val

  ngx.log(ngx.NOTICE,
    "✅ lua (" .. log_context .. " map): URI: ",
    ngx.var.uri,
    ", Target Host: ",
    target_host_val,
    ", New Path: ",
    target_path_val,
    ", Redirect URL: ",
    redirect_url
  )

  ngx.header[header_host_key or "X-Map-WL-Target-Host"] = target_host_val
  ngx.header[header_path_key or "X-Map-WL-Target-Path"] = target_path_val

  return ngx.redirect(redirect_url, status_code)
end

--[[
  Performs an internal redirect (ngx.exec) with logging and setting a custom header.
  @param log_context (string) Context for the log message (e.g., "Knowledge Sharing").
  @param target_location_val (string) Nginx named location for ngx.exec.
  @param header_key_val (string) Header key for the target location.
--]]
local function perform_exec(log_context, target_location_val, header_key_val)
  ngx.log(ngx.NOTICE,
    "✅ lua (" .. log_context .. " map): Executing location '",
    target_location_val,
    "' for URI: ",
    ngx.var.uri
  )
  ngx.header[header_key_val] = target_location_val
  return ngx.exec(target_location_val)
end

--[[
  Handles redirects to services with logging and setting custom headers.
  It is assumed that the redirect_to_service function is globally available.
  @param log_key_display (string) Key for display in the log (e.g., ".id-region").
  @param header_suffix (string) Suffix for the X-WL- header key (e.g., "id-region").
  @param log_value (string) Value for the log and header.
  @param target_http_url (string) URL for redirect (with http://).
  @param target_domain_for_header (string) Domain for the header.
  @param current_host_for_header (string) Current host for the header.
  @param at_service_name (string) Service name (e.g., "@thoth").
--]]
local function handle_service_redirect(log_key_display, header_suffix, log_value, target_http_url, target_domain_for_header, current_host_for_header, at_service_name)
  ngx.log(ngx.NOTICE,
    "✅ ",
    log_key_display .. ": ",
    log_value,
    " HOST: ",
    ngx.var.host,
    " URI: ",
    ngx.var.uri
  )
  ngx.header["X-WL-" .. header_suffix] = log_value
  return redirect_to_service(target_http_url, target_domain_for_header, current_host_for_header, at_service_name) -- redirect_to_service must be defined
end


-- #####################################################################
-- Script Start
-- #####################################################################

local uri = ngx.var.uri
local request_uri = ngx.var.request_uri
local host = ngx.var.host
local args_str = ngx.var.args or ""
local query_prefix = ""

if args_str ~= "" then
  query_prefix = ngx.var.is_args -- Expected that ngx.var.is_args will be "?" or "" (or another necessary prefix)
  if query_prefix == nil or query_prefix == "" then
    query_prefix = "?" -- Defaults to "?" if arguments exist and prefix is not set
  end
else
    query_prefix = "" -- No arguments, no prefix
end

local args = ngx.req.get_uri_args()
local cookie_region = ngx.var.cookie_region
-- local headers = ngx.req.get_headers() -- Declare here if used in multiple send_response calls

ngx.log(ngx.NOTICE,
  "❱❱❱ rewrite_dispatcher.lua (request phase): Executing for URI: ",
  uri,
  ", Args: '",
  args_str,
  "', QueryPrefix: '",
  query_prefix,
  "'"
)

-- Rule 1: Redirect based on ngx.var.redirect_path_current_host
if ngx.var.redirect_path_current_host and ngx.var.redirect_path_current_host ~= "" then
  return perform_redirect(
    "1st current_host",
    host,
    ngx.var.redirect_path_current_host,
    query_prefix,
    args_str,
    301,
    "X-Map-WL-Target-Host",
    "X-Map-WL-Target-Path"
  )
end

-- Rule 2: Redirect based on ngx.var.redirect_path_main_domain
if ngx.var.redirect_path_main_domain and ngx.var.redirect_path_main_domain ~= "" then
  return perform_redirect(
    "1st main_domain",
    ngx.var.main_domain,
    ngx.var.redirect_path_main_domain,
    query_prefix,
    args_str,
    301,
    "X-Map-WL-Target-Host",
    "X-Map-WL-Target-Path"
  )
end

-- Rule 3: Redirect based on ngx.var.ks_redirect_path_redir_domain
if ngx.var.ks_redirect_path_redir_domain and ngx.var.ks_redirect_path_redir_domain ~= "" then
  return perform_redirect(
    "1st redir_domain",
    ngx.var.redir_domain,
    ngx.var.ks_redirect_path_redir_domain,
    query_prefix,
    args_str,
    301,
    "X-Map-WL-Target-Host",
    "X-Map-WL-Target-Path"
  )
end

-- Priority 1: Forced 404s ✅
if ngx.var.force_404_flag == "1" then
  ngx.header["X-Map-WL-force_404_flag"] = ngx.var.force_404_flag
  return send_response(404, " ")
end

-- Priority 2: Production Static ✅
if ngx.var.serve_production_static_flag == "1" then
  ngx.header["X-Map-WL-serve_production_static_flag"] = ngx.var.serve_production_static_flag
  return send_response(200, "production-static (" .. uri .. ")", ngx.req.get_headers()) -- 3 params, not > 4; send_response must be defined
end

-- Priority 3: Knowledge Sharing ngx.exec targets ✅
if ngx.var.knowledge_redirect_target_location and ngx.var.knowledge_redirect_target_location ~= "" then
  -- perform_exec call itself is not subject to the rule (not ngx.log, perform_redirect, or send_response)
  return perform_exec("Knowledge Sharing", ngx.var.knowledge_redirect_target_location, "X-Map-WL-knowledge_redirect_target_location")
end

-- Priority 4: Explorer ngx.exec targets ✅
if ngx.var.explorer_exec_target_location and ngx.var.explorer_exec_target_location ~= "" then
  -- perform_exec call itself is not subject to the rule
  return perform_exec("Explorer", ngx.var.explorer_exec_target_location, "X-Map-WL-explorer_exec_target_location")
end

-- Priority 5: Static 301 Redirects (to current host)
if ngx.var.static_redirect_new_path and ngx.var.static_redirect_new_path ~= "" then
  return perform_redirect(
    "Static 301",
    host,
    ngx.var.static_redirect_new_path,
    query_prefix,
    args_str,
    301,
    nil, -- header_host_key (uses default)
    "X-Map-WL-static_redirect_new_path"
  )
end

-- Priority 6: Redirect old wellnessliving paths to /explore/ ✅
if ngx.var.redirect_old_to_explore_path and ngx.var.redirect_old_to_explore_path ~= "" then
  return perform_redirect(
    "Old WL to Explore",
    host,
    ngx.var.redirect_old_to_explore_path,
    query_prefix,
    args_str,
    301,
    nil, -- header_host_key (uses default)
    "X-Map-WL-redirect_old_to_explore_path"
  )
end

-- Priority 7: Trailing slash for /v/FITNESS-BUSINESS-INSIDER...
if ngx.var.v_series_trailing_slash_check == "1" then
  ngx.log(ngx.NOTICE,
    "✅ rewrite_dispatcher.lua (Map): Adding trailing slash for /v/FITNESS-BUSINESS-INSIDER series (exact): ",
    uri,
    ", Target Host: ",
    ngx.var.main_domain
  )
  ngx.header["X-Map-WL-v_series_trailing_slash_check"] = ngx.var.v_series_trailing_slash_check
  local redirect_url = "https://" .. ngx.var.main_domain .. uri .. query_prefix .. args_str -- uri already contains the path
  return ngx.redirect(redirect_url, 302)
end

-- Priority 8: Trailing slash for /explore ✅
if ngx.var.explore_trailing_slash_check == "1" then
  ngx.header["X-Map-WL-explore_trailing_slash_check"] = ngx.var.explore_trailing_slash_check
  local redirect_url = uri .. "/" .. query_prefix .. args_str
  return ngx.redirect(redirect_url, 302)
end


ngx.log(ngx.NOTICE, "❌ rewrite_dispatcher.lua (request phase): No map-based actions triggered for URI: ", uri)

-- Check for .php in the original request_uri
if request_uri:match("%.php$") then
  -- send_response must be defined
end

-- Redirects based on .id-region
if (args[".id-region"] == "1" or args[".id-region"] == "2") and host == ngx.var.main_domain then
  -- handle_service_redirect call itself is not subject to the rule
  return handle_service_redirect(".id-region", "id-region", args[".id-region"], string.format("http://%s", ngx.var.monolith_demo_domain), ngx.var.monolith_demo_domain, host, "@thoth")
end

-- Redirect based on cookie_region
if cookie_region == "au" and host == ngx.var.main_domain then
  -- handle_service_redirect call itself is not subject to the rule
  return handle_service_redirect("cookie_region", "cookie_region", cookie_region, "http://demox.wellnessliving.com", "demox.wellnessliving.com", host, "@thoth")
end

-- Test redirect based on qwe=10 argument
if args["qwe"] == "10" then
  ngx.log(ngx.NOTICE,
    "✅ ",
    "args: ",
    args["qwe"],
    " HOST: ",
    host,
    " URI: ",
    uri
  )
  -- send_response must be defined
end

-- If none of the conditions are met, the script finishes, and Nginx continues request processing.
