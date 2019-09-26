package client

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
)

const (
	mediaType = "application/json"
	userAgent = "bookingService/1.0"
)

// Client ...
type Client struct {
	// HTTP client used to communicate with the API.
	client *http.Client

	// Base URL for API requests.
	BaseURL *url.URL

	// User agent for client
	UserAgent string

	// Optional function called after every successful request made.
	onRequestCompleted RequestCompletionCallback
}

// RequestCompletionCallback defines the type of the request callback function
type RequestCompletionCallback func(*http.Request, *http.Response, interface{})

// NewClient returns a new HTTP API client.
func NewClient() (*Client, error) {

	httpClient := http.DefaultClient

	c := &Client{httpClient, nil, userAgent, nil}

	return c, nil
}

// NewRequest creates a request
func (c *Client) NewRequest(ctx context.Context, method, urlStr string, body interface{}) (*http.Request, error) {
	rel, errp := url.Parse(urlStr)
	if errp != nil {
		return nil, errp
	}

	u := c.BaseURL.ResolveReference(rel)

	buf := new(bytes.Buffer)

	if body != nil {
		err := json.NewEncoder(buf).Encode(body)

		if err != nil {
			return nil, err
		}
	}
	req, err := http.NewRequest(method, u.String(), buf)

	if err != nil {
		return nil, err
	}

	req.Header.Add("Content-Type", mediaType)
	req.Header.Add("Accept", mediaType)
	req.Header.Add("User-Agent", c.UserAgent)

	return req, nil
}

// OnRequestCompleted sets the DO API request completion callback
func (c *Client) OnRequestCompleted(rc RequestCompletionCallback) {
	c.onRequestCompleted = rc
}

// Do performs request passed
func (c *Client) Do(ctx context.Context, req *http.Request, v interface{}) error {
	req = req.WithContext(ctx)
	resp, err := c.client.Do(req)

	if err != nil {
		return err
	}
	defer func() {
		if rerr := resp.Body.Close(); err == nil {
			err = rerr
		}
	}()

	err = CheckResponse(resp)

	if err != nil {
		return err
	}

	if v != nil {
		if w, ok := v.(io.Writer); ok {
			_, err = io.Copy(w, resp.Body)
			if err != nil {
				return err
			}
		} else {
			err = json.NewDecoder(resp.Body).Decode(v)
			if err != nil {
				return fmt.Errorf("error unmarshalling json: %s", err)
			}
		}
	}

	if c.onRequestCompleted != nil {
		c.onRequestCompleted(req, resp, v)
	}

	return err
}

// CheckResponse checks errors if exist errors in request
func CheckResponse(r *http.Response) error {
	if c := r.StatusCode; c >= 200 && c <= 299 {
		return nil
	}

	v := new(map[string]interface{})
	e := json.NewDecoder(r.Body).Decode(v)

	return errors.New(fmt.Errorf("An error has occured in remote service: STATUS CODE: %d \n %v", r.StatusCode, e).Error())
}

func fillStruct(data map[string]interface{}, result interface{}) error {
	j, err := json.Marshal(data)
	if err != nil {
		return err
	}
	return json.Unmarshal(j, result)
}
