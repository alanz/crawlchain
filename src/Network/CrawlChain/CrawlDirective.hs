module Network.CrawlChain.CrawlDirective where

import Network.CrawlChain.CrawlAction
import Network.CrawlChain.CrawlResult

data CrawlDirective =
    SimpleDirective (String -> [CrawlAction])          -- access content to find absolute follow-up urls
  | RelativeDirective (String -> [CrawlAction])        -- as simple, but found relative urls are completed
  | FollowUpDirective (CrawlResult -> [CrawlAction])   -- as simple, but with access to complete result
  | AlternativeDirective CrawlDirective CrawlDirective -- fallback to second argument if first yields no results
  | RestartChainDirective (CrawlAction, CrawlDirective)-- the possibility to start over (when using alternative)
  | DirectiveSequence [CrawlDirective]                 -- chaining of directives