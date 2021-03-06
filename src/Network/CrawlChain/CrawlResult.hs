module Network.CrawlChain.CrawlResult where

import Network.CrawlChain.CrawlAction

data CrawlResult = CrawlResult {
  crawlingAction :: CrawlAction,
  crawlingContent :: String,
  crawlingResultStatus :: CrawlingResultStatus
} deriving Show

data CrawlingResultStatus = CrawlingOk
                          | CrawlingRedirect String
                          | CrawlingFailed String
  deriving (Show, Eq)
