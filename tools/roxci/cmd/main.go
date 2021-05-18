package main

import (
	"github.com/spf13/cobra"
	"github.com/stackrox/workflow/tools/roxci"
	"os"
)

func main() {
	cmd := &cobra.Command{}

	cmd.AddCommand(
		roxci.CheckCommand(),
	)

	if err := cmd.Execute(); err != nil {
		os.Exit(1)
	}
}
