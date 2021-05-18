package roxci

import (
	"github.com/pkg/errors"
	"regexp"
	"strings"
)

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
				exclude = append(exclude, strings.Split(argPieces[1],",")...)
			case "include":
				include = append(include, strings.Split(argPieces[1],",")...)
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
