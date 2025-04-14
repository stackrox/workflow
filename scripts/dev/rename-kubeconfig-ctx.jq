#!/usr/bin/env -S jq -f
. as $cfg
| (
  # Build context_map as an array of objects with name transformations.
  $cfg.contexts
  | map({
      old_name: .name,
      cluster: .context.cluster,
      old_user: .context.user,
      new_name: .context.cluster,
      new_user: (.context.user + "@" + .context.cluster)
    })
) as $context_map
# Reconstruct the config from scratch.
| {
  kind: $cfg.kind,
  apiVersion: $cfg.apiVersion,
  preferences: $cfg.preferences,
  clusters: $cfg.clusters,
  contexts: (
    $context_map
    | map({
        name: .new_name,
        context: {
          cluster: .cluster,
          user: .new_user
        }
      })
  ),
  users: (
    $cfg.users
    | map(
        . as $user
        | (
            $context_map
            | map(select(.old_user == $user.name))
            | if length > 0 then
                {
                  name: .[0].new_user,
                  user: $user.user
                }
              else
                $user
              end
          )
      )
  ),
}
# Conditionally include current-context if it existed originally.
| if $cfg | has("current-context") then
  . + {
    "current-context": (
      $cfg["current-context"] as $curr
      | $context_map
      | map(select(.old_name == $curr))
      | if length > 0 then .[0].new_name else $curr end
    )
  }
else .
end

