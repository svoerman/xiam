#!/bin/bash

# Fix unused variables in users_live.ex
sed -i '' 's/{:ok, updated_user} ->/{:ok, _updated_user} ->/g' /Users/sander/dev/xiam/lib/xiam_web/live/admin/users_live.ex
sed -i '' 's/defp refresh_users(socket) do/defp refresh_users(_socket) do/g' /Users/sander/dev/xiam/lib/xiam_web/live/admin/users_live.ex

# Fix unused aliases in admin_auth_plug.ex
sed -i '' 's/alias XIAM.Users.User/#alias XIAM.Users.User/g' /Users/sander/dev/xiam/lib/xiam_web/plugs/admin_auth_plug.ex
sed -i '' 's/alias XIAM.RBAC.Role/#alias XIAM.RBAC.Role/g' /Users/sander/dev/xiam/lib/xiam_web/plugs/admin_auth_plug.ex
sed -i '' 's/alias XIAM.RBAC.Capability/#alias XIAM.RBAC.Capability/g' /Users/sander/dev/xiam/lib/xiam_web/plugs/admin_auth_plug.ex

# Fix unused section variable in settings_live.ex
sed -i '' 's/defp db_setting_key(section, key) do/defp db_setting_key(_section, key) do/g' /Users/sander/dev/xiam/lib/xiam_web/live/admin/settings_live.ex
sed -i '' 's/alias XIAM.Repo/#alias XIAM.Repo/g' /Users/sander/dev/xiam/lib/xiam_web/live/admin/settings_live.ex

# Fix unused aliases in api/auth_controller.ex
sed -i '' 's/alias XIAM.Users.User/#alias XIAM.Users.User/g' /Users/sander/dev/xiam/lib/xiam_web/controllers/api/auth_controller.ex
sed -i '' 's/alias XIAM.Repo/#alias XIAM.Repo/g' /Users/sander/dev/xiam/lib/xiam_web/controllers/api/auth_controller.ex
