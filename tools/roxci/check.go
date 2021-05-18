package roxci

import (
	"bytes"
	"fmt"
	"github.com/google/martian/log"
	"github.com/pkg/errors"
	"github.com/spf13/cobra"
	"os"
	"os/exec"
	"regexp"
	"strings"
)

func CheckCommand() *cobra.Command {
	// $ roxci check <job name>
	cmd := &cobra.Command{
		Use:   "check <job name>",
		Short: "Check if a job should run in CI",
		Long: `Check if a job should run in CI.
The exit status can be used to decide whether or not to run a job:
  0 => run
  1 => do not run
any other exit status implies that an error occurred but the job should still run.`,
		Args: cobra.ExactArgs(1),
		Run: func(cmd *cobra.Command, args []string) {
			log.SetLevel(log.Info)

			git := exec.Command("git", "cherry", "-v", "master")

			var outb bytes.Buffer
			git.Stdout = &outb
			git.Stderr = &outb

			err := git.Run()
			if err != nil {
				log.Errorf("Cannot list commits: %v", err)
				fmt.Print(outb.String())
				os.Exit(2)
			}
			os.Exit(0)
		},
	}

	return cmd
}

func Check(job string, commitMessages []string, recipes *[]Recipe) (bool, error) {
	roxciCommandRe := regexp.MustCompile(`(?i)\s*/roxci (.*)`)
	var roxciCommandStr string
	for _, message := range commitMessages {
		if subMatch := roxciCommandRe.FindStringSubmatch(message); len(subMatch) == 2 {
			roxciCommandStr = subMatch[1]
			break
		}
	}
	if roxciCommandStr == "" {
		return true, nil
	}
	roxciCommandStr = strings.ToLower(roxciCommandStr)

	var exclude []string
	var include []string
	pieces := strings.Split(roxciCommandStr, " ")
	if len(pieces) >= 1 {
		for _, argString := range pieces[1:] {
			argPieces := strings.Split(argString, "=")
			if len(argPieces) != 2 {
				return true, errors.Errorf(
					"%s is an unexpected /roxci arg",
					argString,
				)
			}
			switch argPieces[0] {
			case "exclude":
				exclude = append(exclude, strings.Split(argPieces[1], ",")...)
			case "include":
				include = append(include, strings.Split(argPieces[1], ",")...)
			default:
				return true, errors.Errorf(
					"%s is an unexpected /roxci arg",
					argString,
				)
			}
		}
		for _, excluded := range exclude {
			if job == excluded {
				return false, nil
			}
		}
		for _, included := range include {
			if job == included {
				return true, nil
			}
		}
		return checkRunRecipeForJob(job, pieces[0], recipes)
	}

	return true, nil
}

func checkRunRecipeForJob(runJob string, runRecipe string, recipes *[]Recipe) (bool, error) {
	pieces := strings.Split(runRecipe, "=")
	if len(pieces) == 2 {
		if pieces[0] != "recipe" {
			return true, errors.Errorf(
				"the /roxci recipe arg does not have recipe=<recipe> as expected (%s)",
				runRecipe,
			)
		}
		runRecipe = pieces[1]
	}
	if runRecipe == "default" {
		return true, nil
	}
	for _, recipe := range *recipes {
		if recipe.Name == runRecipe {
			for job, _ := range recipe.Jobs {
				if job == runJob {
					return true, nil
				}
			}
			return false, nil
		}
		return true, errors.New("there is no such recipe: " + runRecipe)
	}
	return true, nil
}