alias k="kubectl -n stackrox"

alias ksensordelete="k delete pod -l app=sensor"
alias ksensorlogs="k logs -f -lapp=sensor"
alias ksensoryaml="k get pod -lapp=sensor -o yaml"

alias kcentraldelete="k delete pod -l app=central"
alias kcentrallogs="k logs -f -lapp=central"
alias kcentralyaml="k get pod -lapp=central -o yaml"
alias kcentralport="k port-forward svc/central 8000:443"
