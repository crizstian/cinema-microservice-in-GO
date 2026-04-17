package main

import (
	"bytes"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"text/template"

	"gopkg.in/yaml.v3"
)

type Values map[string]interface{}

func main() {
	var (
		service     = flag.String("service", "", "Service name (e.g., booking)")
		infra       = flag.String("infra", "", "Infrastructure component (mongodb, jaeger, ingress-nginx, or 'all')")
		environment = flag.String("env", "dev", "Environment (dev, staging, prod)")
		version     = flag.String("version", "latest", "Version tag")
		outputDir   = flag.String("output", "", "Output directory")
		baseDir     = flag.String("base", ".", "Base directory for kubernetes configs")
	)
	flag.Parse()

	if *service == "" && *infra == "" {
		fmt.Fprintln(os.Stderr, "Error: -service or -infra is required")
		flag.Usage()
		os.Exit(1)
	}

	if *infra != "" {
		if err := renderInfra(*baseDir, *infra, *outputDir); err != nil {
			fmt.Fprintf(os.Stderr, "Error rendering infrastructure: %v\n", err)
			os.Exit(1)
		}
		return
	}

	if *outputDir == "" {
		*outputDir = filepath.Join(*baseDir, "rendered", *environment, *service)
	}

	values, err := loadValues(*baseDir, *service, *environment, *version)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading values: %v\n", err)
		os.Exit(1)
	}

	if err := renderTemplates(*baseDir, "templates/services", *outputDir, values); err != nil {
		fmt.Fprintf(os.Stderr, "Error rendering templates: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Rendered templates to: %s\n", *outputDir)
}

func renderInfra(baseDir, component, outputDir string) error {
	values, err := loadInfraValues(baseDir)
	if err != nil {
		return fmt.Errorf("loading infrastructure values: %w", err)
	}

	if outputDir == "" {
		outputDir = filepath.Join(baseDir, "rendered", "infrastructure")
	}

	components := []string{component}
	if component == "all" {
		components = []string{"mongodb", "ingress-nginx"}
	}

	for _, comp := range components {
		templateFile := filepath.Join(baseDir, "templates", "infrastructure", comp+".yaml")
		if _, err := os.Stat(templateFile); os.IsNotExist(err) {
			return fmt.Errorf("template not found: %s", templateFile)
		}

		if err := renderSingleTemplate(baseDir, templateFile, outputDir, comp+".yaml", values); err != nil {
			return fmt.Errorf("rendering %s: %w", comp, err)
		}
	}

	fmt.Printf("Rendered infrastructure to: %s\n", outputDir)
	return nil
}

func loadInfraValues(baseDir string) (Values, error) {
	values := make(Values)

	infraFile := filepath.Join(baseDir, "values", "infrastructure.yaml")
	data, err := os.ReadFile(infraFile)
	if err != nil {
		return nil, fmt.Errorf("reading %s: %w", infraFile, err)
	}

	if err := yaml.Unmarshal(data, &values); err != nil {
		return nil, fmt.Errorf("parsing %s: %w", infraFile, err)
	}

	return values, nil
}

func renderSingleTemplate(baseDir, templatePath, outputDir, outputName string, values Values) error {
	if err := os.MkdirAll(outputDir, 0755); err != nil {
		return fmt.Errorf("creating output directory: %w", err)
	}

	funcMap := template.FuncMap{
		"default": func(def interface{}, val interface{}) interface{} {
			if val == nil || val == "" {
				return def
			}
			return val
		},
		"quote": func(val interface{}) string {
			if val == nil {
				return `""`
			}
			return fmt.Sprintf(`"%v"`, val)
		},
		"indent": func(spaces int, val string) string {
			pad := strings.Repeat(" ", spaces)
			return pad + strings.ReplaceAll(val, "\n", "\n"+pad)
		},
		"nindent": func(spaces int, val string) string {
			pad := strings.Repeat(" ", spaces)
			return "\n" + pad + strings.ReplaceAll(val, "\n", "\n"+pad)
		},
		"toYaml": func(val interface{}) string {
			b, _ := yaml.Marshal(val)
			return strings.TrimSpace(string(b))
		},
		"lower":     strings.ToLower,
		"upper":     strings.ToUpper,
		"title":     strings.Title,
		"contains":  strings.Contains,
		"hasPrefix": strings.HasPrefix,
		"hasSuffix": strings.HasSuffix,
		"replace":   strings.ReplaceAll,
		"trim":      strings.TrimSpace,
	}

	content, err := os.ReadFile(templatePath)
	if err != nil {
		return fmt.Errorf("reading template: %w", err)
	}

	tmpl, err := template.New(outputName).Funcs(funcMap).Parse(string(content))
	if err != nil {
		return fmt.Errorf("parsing template: %w", err)
	}

	var buf bytes.Buffer
	data := map[string]interface{}{
		"Values": values,
	}

	if err := tmpl.Execute(&buf, data); err != nil {
		return fmt.Errorf("executing template: %w", err)
	}

	output := strings.TrimSpace(buf.String())
	if output == "" || output == "---" {
		return nil
	}

	outputPath := filepath.Join(outputDir, outputName)
	if err := os.WriteFile(outputPath, []byte(output+"\n"), 0644); err != nil {
		return fmt.Errorf("writing %s: %w", outputPath, err)
	}

	fmt.Printf("Rendered: %s\n", outputPath)
	return nil
}

func loadValues(baseDir, service, environment, version string) (Values, error) {
	values := make(Values)

	files := []string{
		filepath.Join(baseDir, "values", "base.yaml"),
		filepath.Join(baseDir, "values", "environments", environment+".yaml"),
		filepath.Join(baseDir, "values", "services", service+".yaml"),
	}

	for _, file := range files {
		if _, err := os.Stat(file); os.IsNotExist(err) {
			continue
		}

		data, err := os.ReadFile(file)
		if err != nil {
			return nil, fmt.Errorf("reading %s: %w", file, err)
		}

		var fileValues Values
		if err := yaml.Unmarshal(data, &fileValues); err != nil {
			return nil, fmt.Errorf("parsing %s: %w", file, err)
		}

		mergeValues(values, fileValues)
	}

	values["version"] = version
	values["serviceName"] = service

	return values, nil
}

func mergeValues(dst, src Values) {
	for k, v := range src {
		srcMap := toStringMap(v)
		if srcMap != nil {
			dstMap := toStringMap(dst[k])
			if dstMap != nil {
				mergeValues(Values(dstMap), Values(srcMap))
				continue
			}
			dst[k] = srcMap
			continue
		}
		dst[k] = v
	}
}

func toStringMap(v interface{}) map[string]interface{} {
	switch m := v.(type) {
	case map[string]interface{}:
		return m
	case Values:
		return map[string]interface{}(m)
	case map[interface{}]interface{}:
		return convertMap(m)
	}
	return nil
}

func convertMap(m map[interface{}]interface{}) map[string]interface{} {
	result := make(map[string]interface{})
	for k, v := range m {
		key := fmt.Sprintf("%v", k)
		if nested, ok := v.(map[interface{}]interface{}); ok {
			result[key] = convertMap(nested)
		} else {
			result[key] = v
		}
	}
	return result
}

func renderTemplates(baseDir, templatesSubdir, outputDir string, values Values) error {
	templatesDir := filepath.Join(baseDir, templatesSubdir)

	if err := os.MkdirAll(outputDir, 0755); err != nil {
		return fmt.Errorf("creating output directory: %w", err)
	}

	funcMap := template.FuncMap{
		"default": func(def interface{}, val interface{}) interface{} {
			if val == nil || val == "" {
				return def
			}
			return val
		},
		"quote": func(val interface{}) string {
			if val == nil {
				return `""`
			}
			return fmt.Sprintf(`"%v"`, val)
		},
		"indent": func(spaces int, val string) string {
			pad := strings.Repeat(" ", spaces)
			return pad + strings.ReplaceAll(val, "\n", "\n"+pad)
		},
		"nindent": func(spaces int, val string) string {
			pad := strings.Repeat(" ", spaces)
			return "\n" + pad + strings.ReplaceAll(val, "\n", "\n"+pad)
		},
		"toYaml": func(val interface{}) string {
			b, _ := yaml.Marshal(val)
			return strings.TrimSpace(string(b))
		},
		"required": func(msg string, val interface{}) (interface{}, error) {
			if val == nil || val == "" {
				return nil, fmt.Errorf("required: %s", msg)
			}
			return val, nil
		},
		"lower": strings.ToLower,
		"upper": strings.ToUpper,
		"title": strings.Title,
		"contains": strings.Contains,
		"hasPrefix": strings.HasPrefix,
		"hasSuffix": strings.HasSuffix,
		"replace":   strings.ReplaceAll,
		"trim":      strings.TrimSpace,
	}

	helpersPath := filepath.Join(templatesDir, "_helpers.tpl")
	var helpersTmpl *template.Template
	if _, err := os.Stat(helpersPath); err == nil {
		helpersContent, err := os.ReadFile(helpersPath)
		if err != nil {
			return fmt.Errorf("reading helpers: %w", err)
		}
		helpersTmpl, err = template.New("helpers").Funcs(funcMap).Parse(string(helpersContent))
		if err != nil {
			return fmt.Errorf("parsing helpers: %w", err)
		}
	}

	entries, err := os.ReadDir(templatesDir)
	if err != nil {
		return fmt.Errorf("reading templates directory: %w", err)
	}

	for _, entry := range entries {
		if entry.IsDir() || strings.HasPrefix(entry.Name(), "_") {
			continue
		}

		if !strings.HasSuffix(entry.Name(), ".yaml") && !strings.HasSuffix(entry.Name(), ".yml") {
			continue
		}

		templatePath := filepath.Join(templatesDir, entry.Name())
		content, err := os.ReadFile(templatePath)
		if err != nil {
			return fmt.Errorf("reading template %s: %w", entry.Name(), err)
		}

		tmpl := template.New(entry.Name()).Funcs(funcMap)
		if helpersTmpl != nil {
			for _, t := range helpersTmpl.Templates() {
				if t.Name() != "helpers" {
					tmpl.AddParseTree(t.Name(), t.Tree)
				}
			}
		}

		tmpl, err = tmpl.Parse(string(content))
		if err != nil {
			return fmt.Errorf("parsing template %s: %w", entry.Name(), err)
		}

		var buf bytes.Buffer
		data := map[string]interface{}{
			"Values": values,
		}

		if err := tmpl.Execute(&buf, data); err != nil {
			return fmt.Errorf("executing template %s: %w", entry.Name(), err)
		}

		output := strings.TrimSpace(buf.String())
		if output == "" || output == "---" {
			continue
		}

		outputPath := filepath.Join(outputDir, entry.Name())
		if err := os.WriteFile(outputPath, []byte(output+"\n"), 0644); err != nil {
			return fmt.Errorf("writing %s: %w", outputPath, err)
		}

		fmt.Printf("Rendered: %s\n", outputPath)
	}

	return nil
}
