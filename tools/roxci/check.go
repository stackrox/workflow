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
		Short: "Check if a job should be skipped in CI",
		Long: `Check if a job should be skipped in CI.
The exit code can be used to decide whether or not to run a job:
  0 => skip this job
  1 => run
any other exit code implies that an error occurred but the job should still be run.`,
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
			commits := strings.Split(outb.String(), "\n")
			for i, j := 0, len(commits)-1; i < j; i, j = i+1, j-1 {
				commits[i], commits[j] = commits[j], commits[i]
			}

			configFile, ok := os.LookupEnv("ROXCI_CONFIG_FILE")
			if !ok {
				configFile = ".circleci/roxci.yml"
			}
			recipes, err := LoadRecipes(configFile)
			if err != nil {
				log.Errorf("Cannot load recipes: %v", err)
				os.Exit(2)
			}

			run, err := Check(args[0], commits, recipes)
			if err != nil {
				log.Errorf("Check failed: %v", err)
				os.Exit(2)
			}

			if run {
				os.Exit(1)
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
			log.Infof("Checking against commit message: %s", message)
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
				log.Infof("Job '%s' is explicitly excluded", job)
				return false, nil
			}
		}
		for _, included := range include {
			if job == included {
				log.Infof("Job '%s' is explicitly included", job)
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

	log.Infof("Checking for job '%s' in recipe '%s'", runJob, runRecipe)

	for _, recipe := range *recipes {
		if recipe.Name == runRecipe {
			for job, _ := range recipe.Jobs {
				if job == runJob {
					log.Infof("Job '%s' is included", runJob)
					return true, nil
				}
			}
			log.Infof("Job '%s' is not included", runJob)
			return false, nil
		}
	}
	return true, errors.New("there is no such recipe: " + runRecipe)
}
