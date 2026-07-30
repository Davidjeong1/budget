package com.davidjeong.ledger.ui.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.davidjeong.ledger.ui.addedit.AddEditScreen
import com.davidjeong.ledger.ui.home.HomeScreen
import com.davidjeong.ledger.ui.settings.SettingsScreen

private const val ROUTE_HOME = "home"
private const val ROUTE_SETTINGS = "settings"
private const val ARG_TRANSACTION_ID = "transactionId"
private const val ROUTE_ADD_EDIT = "addEdit/{$ARG_TRANSACTION_ID}"

@Composable
fun LedgerNavHost() {
    val navController = rememberNavController()

    NavHost(navController = navController, startDestination = ROUTE_HOME) {
        composable(ROUTE_HOME) {
            HomeScreen(
                onAddTransaction = { navController.navigate("addEdit/0") },
                onEditTransaction = { id -> navController.navigate("addEdit/$id") },
                onOpenSettings = { navController.navigate(ROUTE_SETTINGS) },
            )
        }

        composable(
            route = ROUTE_ADD_EDIT,
            arguments = listOf(navArgument(ARG_TRANSACTION_ID) { type = NavType.LongType }),
        ) { entry ->
            AddEditScreen(
                transactionId = entry.arguments?.getLong(ARG_TRANSACTION_ID) ?: 0L,
                onNavigateBack = { navController.popBackStack() },
            )
        }

        composable(ROUTE_SETTINGS) {
            SettingsScreen(onNavigateBack = { navController.popBackStack() })
        }
    }
}
