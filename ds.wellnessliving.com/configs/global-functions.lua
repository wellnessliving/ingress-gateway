function redirect_to_service(service_url, service_host, original_host, location)
  ngx.var.proxy_pass_url = service_url
  ngx.req.set_header("Host", service_host)
  ngx.req.set_header("X-Host", original_host)
  return ngx.exec(location)
end
--
function send_response(status, body, headers, content_type, http_host, uri)
if not status then
  status = ngx.HTTP_INTERNAL_SERVER_ERROR
end
  ngx.status = status
  content_type = content_type or "text/plain"
  ngx.header.content_type = content_type
if headers and type(headers) == "table" then
  for key, value in pairs(headers) do
    ngx.header[key] = value
  end
end
if body and body ~= "" then
  ngx.say(body)
end
if http_host and http_host ~= "" then
  ngx.say(string.format("http_host: %s", http_host))
end
if uri and uri ~= "" then
  ngx.say(string.format("uri: %s", uri))
end
return status
end
-- ###
--function handle_error()
-- local error_routes = {
    -- ["400"] = "thoth.downpage.demo.wellnessliving.com/400/",
    -- ["401"] = "thoth.downpage.demo.wellnessliving.com/401/",
    -- ["403"] = "thoth.downpage.demo.wellnessliving.com/403/",
    -- ["404"] = "thoth.downpage.demo.wellnessliving.com/404/",
    -- ["408"] = "thoth.downpage.demo.wellnessliving.com/408/",
    -- ["429"] = "thoth.downpage.demo.wellnessliving.com/429/",
    -- ["500"] = "thoth.downpage.demo.wellnessliving.com/500/",
    -- ["502"] = "thoth.downpage.demo.wellnessliving.com/502/",
    -- ["503"] = "thoth.downpage.demo.wellnessliving.com/503/",
    -- ["504"] = "thoth.downpage.demo.wellnessliving.com/504/",
    -- ["507"] = "thoth.downpage.demo.wellnessliving.com/507/"
    --
-- }
-- local status = tostring(ngx.status)
-- -local redirect_url = error_routes[status]
-- ngx.log(ngx.ERR, "[DEBUG] Redirecting to: " .. redirect_url .. ngx.var.request_uri)
-- ngx.var.proxy_pass_url = "http://" .. redirect_url
-- ngx.req.set_header("X-Host", ngx.var.http_host)
-- end
-- ###
--
-- This function is intended to be called from an access_by_lua_block
-- within the @error_page named location.
-- Its primary role is to set the ngx.var.proxy_pass_url variable
-- which will be used by a subsequent `proxy_pass` directive in the same location.
-- If no specific error page is configured for the status, it sends a fallback response.
function handle_error()
-- Table mapping error status codes to the target host and path for proxying.
local error_routes = {
    ["400"] = "thoth.downpage.demo.wellnessliving.com/400/",
    ["401"] = "thoth.downpage.demo.wellnessliving.com/401/",
    ["403"] = "thoth.downpage.demo.wellnessliving.com/403/",
    ["404"] = "thoth.downpage.demo.wellnessliving.com/404/",
    ["408"] = "thoth.downpage.demo.wellnessliving.com/408/",
    ["429"] = "thoth.downpage.demo.wellnessliving.com/429/",
    ["500"] = "thoth.downpage.demo.wellnessliving.com/500/",
    ["502"] = "thoth.downpage.demo.wellnessliving.com/502/",
    ["503"] = "thoth.downpage.demo.wellnessliving.com/503/",
    ["504"] = "thoth.downpage.demo.wellnessliving.com/504/",
    ["507"] = "thoth.downpage.demo.wellnessliving.com/507/"
    -- Add other status codes and their corresponding error page URLs here if needed.
}
-- Get the current Nginx status code for the request.
local current_status = ngx.status
if not current_status then
-- If the status is somehow not set (should usually be set by Nginx before error_page),
-- default to 500 Internal Server Error.
  ngx.log(ngx.WARN, "handle_error: ngx.status was nil, defaulting to 500.")
  current_status = ngx.HTTP_INTERNAL_SERVER_ERROR -- Use Nginx Lua constant for 500
  ngx.status = current_status -- Ensure the status is explicitly set
end

-- Convert the status code to a string to use it as a key for the error_routes table.
local status_string = tostring(current_status)
-- Look up the specific host/path defined for this status code.
local redirect_host_path = error_routes[status_string]

-- Check if a specific error page route was found for this status code.
if redirect_host_path then
-- A route was found. Construct the full URL for the proxy_pass target.
  local target_url = "http://" .. redirect_host_path
-- Set the Nginx variable that will be used by the proxy_pass directive later.
  ngx.var.proxy_pass_url = target_url
-- Set the X-Host header, preserving the original host requested by the client.
  ngx.req.set_header("X-Host", ngx.var.http_host)
  ngx.log(ngx.INFO, "handle_error: Handling error status ", status_string, " by setting proxy_pass_url to: ", ngx.var.proxy_pass_url)
-- IMPORTANT: Do NOT call ngx.exit() or ngx.exec() here.
-- This function's job in this branch is only to prepare the variables.
-- Nginx needs to continue processing to reach the `proxy_pass $proxy_pass_url;`
-- directive within the @error_page location block.
else
-- No specific error page route was defined for this status code in the error_routes table.
  ngx.log(ngx.WARN, "handle_error: No specific error route defined for status: ", status_string)
-- In this fallback case, we must generate and send a response directly from Lua,
-- because the subsequent `proxy_pass` directive would not have a valid URL to use.
  ngx.header.content_type = "text/plain; charset=utf-8" -- Set a default content type
  ngx.say("An error occurred. Status code: ", status_string) -- Provide a simple fallback message
-- Terminate the request processing immediately and send the generated response.
  return ngx.exit(current_status)
end
end
