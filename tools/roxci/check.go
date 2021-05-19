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

const (
	COMMIT_ARG_RECIPE  = "recipe"
	COMMIT_ARG_EXCLUDE = "exclude"
	COMMIT_ARG_INCLUDE = "include"
)

var (
	COMMIT_ARGS = map[string]bool{
		COMMIT_ARG_RECIPE:  true,
		COMMIT_ARG_EXCLUDE: true,
		COMMIT_ARG_INCLUDE: true,
	}
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
Any other exit code implies that an error occurred but the job should still be run.`,
		Args: cobra.ExactArgs(1),
		Run:  checkCommand,
	}

	return cmd
}

func checkCommand(cmd *cobra.Command, args []string) {
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

	run, err := check(args[0], commits, recipes)
	if err != nil {
		log.Errorf("Check failed: %v", err)
		os.Exit(2)
	}

	if run {
		os.Exit(1)
	}

	os.Exit(0)
}

func check(job string, commitMessages []string, recipes *[]Recipe) (bool, error) {
	roxciCommandStr := getCommandFromCommits(commitMessages)
	if roxciCommandStr == "" {
		return true, nil
	}

	commitArgs, err := getCommitArgsFromCommand(roxciCommandStr)
	if err != nil {
		return true, err
	}

	for _, excluded := range commitArgs[COMMIT_ARG_EXCLUDE] {
		if job == excluded {
			log.Infof("Job '%s' is explicitly excluded", job)
			return false, nil
		}
	}
	for _, included := range commitArgs[COMMIT_ARG_INCLUDE] {
		if job == included {
			log.Infof("Job '%s' is explicitly included", job)
			return true, nil
		}
	}
	return checkRecipesForJob(job, commitArgs[COMMIT_ARG_RECIPE], recipes)
}

func checkRecipesForJob(checkJob string, checkRecipes []string, recipes *[]Recipe) (bool, error) {
	for _, checkRecipe := range checkRecipes {
		if checkRecipe == "default" {
			return true, nil
		}

		log.Infof("Checking for job '%s' in recipe '%s'", checkJob, checkRecipe)

		recipeFound := false
		for _, recipe := range *recipes {
			if recipe.Name == checkRecipe {
				recipeFound = true
				for job, _ := range recipe.Jobs {
					if job == checkJob {
						log.Infof("Job '%s' is included", checkJob)
						return true, nil
					}
				}
				log.Infof("Job '%s' is not included in recipe '%s'", checkJob, checkRecipe)
			}
		}
		if !recipeFound {
			return true, errors.New("there is no such recipe: " + checkRecipe)
		}
	}
	log.Infof("Job '%s' is not included in any recipes", checkJob)
	return false, nil
}

func getCommandFromCommits(commitMessages []string) string {
	roxciCommandRe := regexp.MustCompile(`(?i)\s*/roxci (.*)`)
	var roxciCommandStr string
	for _, message := range commitMessages {
		if subMatch := roxciCommandRe.FindStringSubmatch(message); len(subMatch) == 2 {
			roxciCommandStr = subMatch[1]
			log.Infof("Checking against commit message: %s", message)
			break
		}
	}
	return strings.ToLower(roxciCommandStr)
}

func getCommitArgsFromCommand(command string) (map[string][]string, error) {

	var commitArgs = map[string][]string{
		COMMIT_ARG_RECIPE:  {},
		COMMIT_ARG_EXCLUDE: {},
		COMMIT_ARG_INCLUDE: {},
	}

	pieces := strings.Split(command, " ")

	for idx, argString := range pieces {
		argPieces := strings.Split(argString, "=")
		if idx == 0 && len(argPieces) == 1 {
			commitArgs[COMMIT_ARG_RECIPE] = append(commitArgs[COMMIT_ARG_RECIPE], strings.Split(argString, ",")...)
			continue
		}
		if len(argPieces) != 2 {
			return nil, errors.Errorf(
				"%s is an unexpected /roxci arg",
				argString,
			)
		}
		if ok := COMMIT_ARGS[argPieces[0]]; !ok {
			return nil, errors.Errorf(
				"%s is an unexpected /roxci arg",
				argString,
			)
		}
		commitArgs[argPieces[0]] = append(commitArgs[argPieces[0]], strings.Split(argPieces[1], ",")...)
	}

	return commitArgs, nil
}
