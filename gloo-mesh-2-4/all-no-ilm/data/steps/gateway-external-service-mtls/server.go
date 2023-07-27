package main

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"bytes"
	"io/ioutil"
	"log"
	"net/http"
	"path/filepath"
)

func printHeader(w *bytes.Buffer, r *http.Request) {
	fmt.Fprintf(w, ">>>>>>>>>>>>>>>> Header <<<<<<<<<<<<<<<<\n")
	for name, values := range r.Header {
		for _, value := range values {
			fmt.Fprintf(w, "%v:%v\n", name, value)
		}
	}
}

func printConnState(w *bytes.Buffer, state *tls.ConnectionState) {
	fmt.Fprintf(w, "\n>>>>>>>>>>>>>>>> TLS State <<<<<<<<<<<<<\n")

	fmt.Fprintf(w, "Version: %x\n", state.Version)
	fmt.Fprintf(w, "HandshakeComplete: %t\n", state.HandshakeComplete)
	fmt.Fprintf(w, "NegotiatedProtocol: %s\n", state.NegotiatedProtocol)
	fmt.Fprintf(w, "NegotiatedProtocolIsMutual: %t\n", state.NegotiatedProtocolIsMutual)
	fmt.Fprintf(w, "DidResume: %t\n", state.DidResume)
	fmt.Fprintf(w, "CipherSuite: %x\n", state.CipherSuite)

	fmt.Fprintf(w, "Certificate chain:")
	for i, cert := range state.PeerCertificates {
		subject := cert.Subject
		issuer := cert.Issuer
		fmt.Fprintf(w, " %d subject:/C=%v/ST=%v/L=%v/O=%v/OU=%v/CN=%s\n", i, subject.Country, subject.Province, subject.Locality, subject.Organization, subject.OrganizationalUnit, subject.CommonName)
		fmt.Fprintf(w, "    issuer:/C=%v/ST=%v/L=%v/O=%v/OU=%v/CN=%s\n", issuer.Country, issuer.Province, issuer.Locality, issuer.Organization, issuer.OrganizationalUnit, issuer.CommonName)
	}
}

func HelloServer(w http.ResponseWriter, req *http.Request) {
	var buf bytes.Buffer
	printHeader(&buf, req)
	printConnState(&buf, req.TLS)
	fmt.Fprintf(&buf, ">>>>>>>>>>>>>>>>> End <<<<<<<<<<<<<<<<<<\n")
	fmt.Fprintf(&buf, "\nHello from mTLS server.\n")
	w.Write(buf.Bytes())
	w.Header().Set("Content-Type", "text/plain")
}

func handleError(err error) {
	if err != nil {
		log.Fatal("Fatal", err)
	}
}

func main() {
	absPathServerCrt, err := filepath.Abs("certs/server.crt")
	handleError(err)
	absPathServerKey, err := filepath.Abs("certs/server.key")
	handleError(err)
	absPathServerCA, err := filepath.Abs("certs/ca.crt")
	handleError(err)

	clientCACert, err := ioutil.ReadFile(absPathServerCA)
	handleError(err)

	clientCertPool := x509.NewCertPool()
	clientCertPool.AppendCertsFromPEM(clientCACert)

	tlsConfig := &tls.Config{
		ClientAuth:               tls.RequireAndVerifyClientCert,
		ClientCAs:                clientCertPool,
		PreferServerCipherSuites: true,
		MinVersion:               tls.VersionTLS12,
	}

	http.HandleFunc("/", HelloServer)
	httpServer := &http.Server{
		Addr:      ":443",
		TLSConfig: tlsConfig,
	}

	fmt.Println("(HTTPS) Listening on: 443")
	err = httpServer.ListenAndServeTLS(absPathServerCrt, absPathServerKey)
	handleError(err)
}
