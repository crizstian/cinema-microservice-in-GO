package smtp

import (
	"bytes"
	"fmt"
	"mime/quotedprintable"
	"net/smtp"
	"strings"

	log "github.com/sirupsen/logrus"
)

// SMTPServer ...
const SMTPServer = "smtp.gmail.com"

// Config ...
type Config struct {
	User     string
	Password string
}

// SendMail ...
func (sender Config) SendMail(dest []string, subject, bodyMessage string) error {

	msg := "From: " + sender.User + "\n" +
		"To: " + strings.Join(dest, ",") + "\n" +
		"Subject: " + subject + "\n" + bodyMessage

	err := smtp.SendMail(SMTPServer+":587",
		smtp.PlainAuth("", sender.User, sender.Password, SMTPServer),
		sender.User, dest, []byte(msg))

	if err != nil {
		return err
	}

	log.Info("Mail sent successfully to " + strings.Join(dest, ","))
	return nil
}

// WriteEmail ...
func (sender Config) WriteEmail(dest []string, contentType, subject, bodyMessage string) string {

	header := make(map[string]string)
	header["From"] = sender.User

	receipient := ""

	for _, user := range dest {
		receipient = receipient + user
	}

	header["MIME-Version"] = "1.0"
	header["Content-Type"] = fmt.Sprintf("%s; charset=\"utf-8\"", contentType)
	header["Content-Transfer-Encoding"] = "quoted-printable"
	header["Content-Disposition"] = "inline"

	message := ""

	for key, value := range header {
		message += fmt.Sprintf("%s: %s\r\n", key, value)
	}

	var encodedMessage bytes.Buffer

	finalMessage := quotedprintable.NewWriter(&encodedMessage)
	finalMessage.Write([]byte(bodyMessage))
	finalMessage.Close()

	message += "\r\n" + encodedMessage.String()

	return message
}

// WriteHTMLEmail ...
func (sender *Config) WriteHTMLEmail(dest []string, subject, bodyMessage string) string {

	return sender.WriteEmail(dest, "text/html", subject, bodyMessage)
}

// WritePlainEmail ...
func (sender *Config) WritePlainEmail(dest []string, subject, bodyMessage string) string {

	return sender.WriteEmail(dest, "text/plain", subject, bodyMessage)
}
