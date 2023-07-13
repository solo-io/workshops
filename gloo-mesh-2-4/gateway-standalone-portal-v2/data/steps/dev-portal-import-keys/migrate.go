package main

import (
	"context"
	"bufio"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"github.com/redis/go-redis/v9"
	"github.com/google/uuid"
	"os"
)

var ctx = context.Background()

func HashKey(key string, secret []byte) string {
	hashedKey := []byte(key)

	// Create a new HMAC by defining the hash type and the key (as byte array)
	h := hmac.New(sha256.New, secret)

	// Write data to it
	h.Write(hashedKey)

	// Get result and encode as base64 string
	return base64.StdEncoding.EncodeToString(h.Sum(nil))
}

func CreateKey(key string, client *redis.Client, secret []byte, authConfigId string, username string, additionalMetadata string) {
	hash := HashKey(key, secret)
	generatedUUID := uuid.NewString()

	err := client.Set(ctx, generatedUUID, hash, 0).Err()
	if err != nil {
		panic(err)
	}

	metadata := fmt.Sprintf("{\"api_key\":\"%s\",\"labels\":[\"%s\"],\"metadata\":{\"config_id\":\"%s\",\"created-ts-unix\":\"1688454771\",\"name\":\"%s\",\"usagePlan\":\"gold\",\"username\":\"%s\",%s},\"uuid\":\"%s\"}", hash, username, authConfigId, generatedUUID, username, additionalMetadata, generatedUUID)

	err2 := client.Set(ctx, hash, metadata, 0).Err()
	if err2 != nil {
		panic(err)
	}

	err3 := client.SAdd(ctx, username, hash).Err()
	if err3 != nil {
		panic(err)
	}

	fmt.Println("key added", key, "to user", username)
}

func main() {
	redisAddr := os.Getenv("REDIS_ADDR")
	client := redis.NewClient(&redis.Options{
		Addr:     redisAddr,
		Password: "",
		DB:       0,
	})

	secret := []byte(os.Getenv("APIKEY_STORAGE_SECRET_KEY"))
	authConfigId := os.Getenv("AUTHCONFIG_ID")
	username := os.Getenv("USERNAME")
	additionalMetadata := os.Getenv("ADDITIONAL_METADATA")

	file, err := os.Open("/run/secrets/apikeys.txt")
	if err != nil {
		panic(err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		CreateKey(scanner.Text(), client, secret, authConfigId, username, additionalMetadata)
	}

	if err := scanner.Err(); err != nil {
		panic(err)
	}
}
