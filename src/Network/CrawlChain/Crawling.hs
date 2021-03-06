module Network.CrawlChain.Crawling (
  crawl,
  crawlAndStore, CrawlActionDescriber,
  Crawler
) where

import Network.HTTP
import Network.Stream (Result)
import Network.URI

import Network.CrawlChain.CrawlAction
import Network.CrawlChain.CrawlResult
import Network.CrawlChain.Util
import Network.URI.Util

type RequestType = Request_String
type Crawler = CrawlAction -> IO CrawlResult
type CrawlActionDescriber = CrawlAction -> String

crawl :: Crawler
crawl action = delaySeconds 1 >> crawl' action 3 (toRequest action)

crawlAndStore :: CrawlActionDescriber -> Crawler
crawlAndStore describer = (>>= store) . crawl
    where
      store :: CrawlResult -> IO CrawlResult
      store cr = store' (crawlingResultStatus cr)
        where
          store' CrawlingOk = storeResult (crawlingContent cr)
          store' (CrawlingFailed msg) = storeResult msg
          store' status = error $ "unexpected status: " ++ (show status)
          storeResult filecontent'= do
            writeFile' (describer $ crawlingAction cr) filecontent'
            return cr
              where
                writeFile' n c = do
                  putStrLn $ "writing to " ++ n
                  writeFile n c

toRequest :: CrawlAction -> RequestType
toRequest (GetRequest url) = addStandardHeader $ mkRequest GET (toURI url)
toRequest (PostRequest url params postType) =
  plainPost {rqBody = formParams,
             rqHeaders = makePostHeaders postType formParams
            }
    where
     plainPost :: RequestType
     plainPost = addStandardHeader $ mkRequest POST (toURI url)
     formParams = urlEncodeVars params

addStandardHeader :: (HasHeaders h) => h -> h
addStandardHeader = insertHeaders [
  Header HdrUserAgent "Mozilla/5.0 (X11; Ubuntu; Linux i686; rv:38.0) Gecko/20100101 Firefox/38.0"
  ]

makePostHeaders :: PostType -> String -> [Header]
makePostHeaders PostForm formParams =
  [
    mkHeader HdrContentType "application/x-www-form-urlencoded",
    mkHeader HdrContentLength (show $ length formParams)
  ]
makePostHeaders PostAJAX formParams = ajaxHeader:(makePostHeaders PostForm formParams) where
  ajaxHeader = mkHeader (HdrCustom "X-Requested-With") "XMLHttpRequest"
makePostHeaders _ _ = []

crawl' :: CrawlAction -> Int -> RequestType -> IO CrawlResult
crawl' originalAction maxRedirects request = do
--  print request
  response <- simpleHTTP request
--  print response
  body <- getResponseBody response
--  print body
  code <- getResponseCode response
  logMsg $ "Crawled " ++ (showRequest request) ++ " with result: " ++ (show code)
  checkRedirect maxRedirects request (crawlResult response body code)
  where
     crawlResult :: (HasHeaders a) => Result a -> String -> ResponseCode -> CrawlResult
     crawlResult response body code = CrawlResult originalAction body (parseResonseCode code (locationHeaders response))
      where
        locationHeaders :: (HasHeaders a) => Result a -> [Header]
        locationHeaders = either (\_ -> []) (retrieveHeaders HdrLocation)

-- this reinvents the wheel and should be switched to using http-client if problems occur
checkRedirect :: Int -> RequestType -> CrawlResult -> IO CrawlResult
checkRedirect 0 _ result = return result
checkRedirect maxRedirects previousRequest result =
  maybe (return result) (crawl' (crawlingAction result) (maxRedirects -1)) (extractRedirectAction $ crawlingResultStatus result)
  where
    extractRedirectAction :: CrawlingResultStatus -> Maybe (Request String)
     -- unclean: converts PostRequest to Get, should do something more sensible
    extractRedirectAction (CrawlingRedirect url) = Just $ previousRequest { rqURI = toURI url }
    extractRedirectAction _ = Nothing

parseResonseCode :: ResponseCode -> [Header] -> CrawlingResultStatus
parseResonseCode (2, _, _) _ = CrawlingOk
parseResonseCode code@(3, _, _) hdrLoc = maybe (CrawlingFailed (show code)) CrawlingRedirect (extractRedirectUrl hdrLoc)
parseResonseCode code _ = CrawlingFailed (show code)

extractRedirectUrl :: [Header] -> Maybe String
extractRedirectUrl [] = Nothing
extractRedirectUrl ((Header _ value):xs) =
  let parsedHeader = (parseURIReference value)
  in maybe (extractRedirectUrl xs) (Just . show) parsedHeader

showRequest :: RequestType -> String
showRequest r = (show $ rqURI r) ++ " - " ++ (show $ rqMethod r) ++ ": " ++ (rqBody r)

