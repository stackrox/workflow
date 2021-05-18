package roxci

import "github.com/pkg/errors"
import "gopkg.in/yaml.v2"
import "io/ioutil"

type Recipe struct {
	Name        string
	Description string
	Jobs        []string
}

func LoadRecipes(filename string) (*[]Recipe, error) {
	data, err := ioutil.ReadFile(filename)
	if err != nil {
		return nil, err
	}

	var recipes []Recipe
	err = yaml.Unmarshal(data, &recipes)
	if err != nil {
		return nil, errors.Wrap(err, "cannot parse recipes")
	}
	for _, recipe := range recipes {
		if recipe.Name == "" {
			return nil, errors.New("recipe found with a missing name")
		}
		if recipe.Description == "" {
			return nil, errors.Errorf("recipe %s is missing a description", recipe.Name)
		}
		if len(recipe.Jobs) == 0 {
			return nil, errors.Errorf("recipe %s is missing jobs", recipe.Name)
		}
	}
	return &recipes, nil
}
